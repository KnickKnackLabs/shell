#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

prepare_login_reader() {
  export SHELL_STARTUP_TEST_DIR="$BATS_TEST_TMPDIR"
  export SHELL_STARTUP_HOME="$BATS_TEST_TMPDIR/home"
  export SHELL_REAL_ZMX="$(command -v zmx)"
  export SHELL_STARTUP_READS="$1"
  mkdir -m 700 "$SHELL_STARTUP_HOME"
  cp "$REPO_DIR/test/fixtures/login-reader.bash" "$SHELL_STARTUP_HOME/.bash_profile"
  export ZMX_BIN="$BATS_TEST_TMPDIR/zmx-with-test-home"
  cat > "$ZMX_BIN" <<'SH'
#!/usr/bin/env bash
exec env HOME="$SHELL_STARTUP_HOME" "$SHELL_REAL_ZMX" "$@"
SH
  chmod +x "$ZMX_BIN"
}

@test "run launches a session and outputs the name" {
  run shell run "${TEST_PREFIX}-basic" echo hello
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${TEST_PREFIX}-basic"
}

@test "run session appears in shell list" {
  shell run "${TEST_PREFIX}-visible" sleep 30
  run shell list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${TEST_PREFIX}-visible"
}

@test "run rejects names starting with a dash" {
  run shell run "--bad-name" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "cannot start with a dash"
}

@test "run rejects invalid characters in name" {
  run shell run "bad name!" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "invalid session name"
}

@test "run fails without a command" {
  run shell run "${TEST_PREFIX}-nocmd"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "command\|arg"
}

@test "run on busy session errors" {
  shell run "${TEST_PREFIX}-dup" sleep 30
  sleep 0.5
  run shell run "${TEST_PREFIX}-dup" echo again
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "busy\|running"
}

@test "run executes the given command" {
  shell run "${TEST_PREFIX}-exec" echo "shell-test-marker"
  # Give it a moment to execute
  sleep 0.5
  run zmx history "${TEST_PREFIX}-exec"
  echo "$output" | grep -q "shell-test-marker"
}

@test "run --cwd sets working directory" {
  TESTDIR=$(mktemp -d)
  shell run "${TEST_PREFIX}-cwd" --cwd "$TESTDIR" pwd
  shell wait "${TEST_PREFIX}-cwd"
  run zmx history "${TEST_PREFIX}-cwd"
  echo "$output" | grep -q "$TESTDIR"
  rmdir "$TESTDIR"
}

@test "run --cwd handles spaces and single quotes" {
  TESTDIR="$BATS_TEST_TMPDIR/dir with spaces and ' quote"
  mkdir -p "$TESTDIR"
  shell run "${TEST_PREFIX}-cwdquote" --cwd "$TESTDIR" bash -c 'pwd > pwd.out'
  shell wait "${TEST_PREFIX}-cwdquote"
  [ -f "$TESTDIR/pwd.out" ]
  grep -Fq "dir with spaces and ' quote" "$TESTDIR/pwd.out"
}

@test "run --cwd errors on nonexistent directory" {
  run shell run "${TEST_PREFIX}-badcwd" --cwd "/tmp/nonexistent-$$" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not found"
}

@test "run --probe-ready executes launcher once without a login reader" {
  prepare_login_reader 0
  session="${TEST_PREFIX}-ready"
  shell run --probe-ready --ready-timeout 5 "$session" bash -c \
    'printf "launched\n" >> "$SHELL_STARTUP_TEST_DIR/launch-effects"'
  shell wait "$session"
  [ "$(cat "$BATS_TEST_TMPDIR/launch-effects")" = launched ]
  [ ! -e "$BATS_TEST_TMPDIR/consumed" ]
  [ "$(cat "$BATS_TEST_TMPDIR/events")" = startup ]
}

@test "run --probe-ready executes launcher once after login consumes a submission" {
  prepare_login_reader 1
  session="${TEST_PREFIX}-reader"
  shell run --probe-ready --ready-timeout 5 "$session" bash -c \
    'printf "launched\n" >> "$SHELL_STARTUP_TEST_DIR/launch-effects"'
  shell wait "$session"
  [ "$(cat "$BATS_TEST_TMPDIR/launch-effects")" = launched ]
  [ -s "$BATS_TEST_TMPDIR/consumed" ]
  [ "$(cat "$BATS_TEST_TMPDIR/events")" = startup ]
}

@test "run --probe-ready retries through three consumed submissions" {
  prepare_login_reader 3
  session="${TEST_PREFIX}-three"
  shell run --probe-ready --ready-timeout 5 "$session" bash -c \
    'printf "launched\n" >> "$SHELL_STARTUP_TEST_DIR/launch-effects"'
  shell wait "$session"
  [ "$(cat "$BATS_TEST_TMPDIR/launch-effects")" = launched ]
  [ "$(wc -l < "$BATS_TEST_TMPDIR/consumed")" -eq 3 ]
}

@test "run --probe-ready timeout never submits the launcher" {
  prepare_login_reader 30
  session="${TEST_PREFIX}-timeout"
  run shell run --probe-ready --ready-timeout 1 "$session" bash -c \
    'printf "launched\n" >> "$SHELL_STARTUP_TEST_DIR/launch-effects"'
  [ "$status" -ne 0 ]
  [[ "$output" == *"did not execute a readiness probe within 1s"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/launch-effects" ]
}

@test "run rejects an excessive readiness timeout" {
  run shell run --probe-ready --ready-timeout 99999999999999999999 "${TEST_PREFIX}-huge" echo nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"--ready-timeout must be an integer from 1 to 300"* ]]
}

@test "run rejects a readiness timeout without opting in" {
  run shell run --ready-timeout 1 "${TEST_PREFIX}-no-probe" echo nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"--ready-timeout requires --probe-ready"* ]]
}

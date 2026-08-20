#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

# --- basic send ---

@test "send delivers text to a running session" {
  # Start cat, which echoes stdin to stdout
  shell run "${TEST_PREFIX}-recv" cat
  sleep 0.5
  shell send "${TEST_PREFIX}-recv" "hello from send"
  sleep 0.5
  run zmx history "${TEST_PREFIX}-recv"
  echo "$output" | grep -q "hello from send"
}

@test "send immediately after run reaches process stdin" {
  shell run "${TEST_PREFIX}-immediate" python3 -u -c 'import sys; print("ready", flush=True); line=sys.stdin.readline(); print("got:" + repr(line), flush=True); sys.stdin.readline()'

  shell send "${TEST_PREFIX}-immediate" "hello immediately"
  sleep 0.5

  run zmx history "${TEST_PREFIX}-immediate"
  echo "$output" | grep -q "hello immediately"
  echo "$output" | grep -q "got:.*hello immediately"
}

@test "send does not inject zmx task completion markers" {
  # Encode the output prefix in the submitted source so terminal history does
  # not contain a false `got:.*ZMX_TASK_COMPLETED` match on the echoed command.
  shell run "${TEST_PREFIX}-marker" python3 -u -c 'import sys; print("\x67\x6f\x74\x3a" + repr(sys.stdin.readline()), flush=True); sys.stdin.readline()'
  sleep 0.5

  shell send "${TEST_PREFIX}-marker" "hello marker check"
  sleep 0.5

  run zmx history "${TEST_PREFIX}-marker"
  echo "$output" | grep -q "got:.*hello marker check"
  ! echo "$output" | grep -q "got:.*ZMX_TASK_COMPLETED"
}

@test "send --raw does not append carriage return" {
  shell run "${TEST_PREFIX}-raw" python3 -u -c 'import sys; print("ready", flush=True); line=sys.stdin.readline(); print("got:" + line, flush=True); sys.stdin.readline()'
  sleep 0.5

  shell send --raw "${TEST_PREFIX}-raw" "partial"
  sleep 0.5
  run zmx history "${TEST_PREFIX}-raw"
  ! echo "$output" | grep -q "got:partial"

  printf '\r' | shell send --raw "${TEST_PREFIX}-raw"
  sleep 0.5
  run zmx history "${TEST_PREFIX}-raw"
  echo "$output" | grep -q "got:partial"
}

@test "send forwards piped stdin exactly" {
  shell run "${TEST_PREFIX}-stdin" python3 -u -c 'import sys; print("ready", flush=True); print("got1:" + sys.stdin.readline(), flush=True); print("got2:" + sys.stdin.readline(), flush=True); sys.stdin.readline()'
  sleep 0.5

  printf 'alpha\rbravo\r' | shell send "${TEST_PREFIX}-stdin"
  sleep 0.5

  run zmx history "${TEST_PREFIX}-stdin"
  echo "$output" | grep -q "got1:alpha"
  echo "$output" | grep -q "got2:bravo"
}

@test "send errors on nonexistent session" {
  run shell send "nonexistent-$$" "hello"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

@test "send errors with no input" {
  shell run "${TEST_PREFIX}-noinput" sleep 30
  run shell send "${TEST_PREFIX}-noinput"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "input\|message\|arg"
}

@test "send with no input refuses interactive stdin" {
  session="${TEST_PREFIX}-tty-noinput"
  shell run "$session" sleep 30

  run python3 - "$REPO_DIR" "$session" <<'PY'
import os
import pty
import subprocess
import sys

repo, name = sys.argv[1], sys.argv[2]
master, slave = pty.openpty()
try:
    proc = subprocess.Popen(
        ["mise", "-C", repo, "run", "-q", "send", name],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=os.environ.copy(),
    )
finally:
    os.close(slave)

try:
    output, _ = proc.communicate(timeout=2)
except subprocess.TimeoutExpired:
    proc.kill()
    output, _ = proc.communicate()
    print(output, end="")
    sys.exit(124)
finally:
    os.close(master)

print(output, end="")
sys.exit(proc.returncode)
PY

  [ "$status" -ne 0 ]
  [ "$status" -ne 124 ]
  echo "$output" | grep -qi "input required"
}

# --- shell run on existing sessions ---

@test "run on an existing completed session refuses unproven prompt reuse" {
  shell run "${TEST_PREFIX}-reuse" echo first
  shell wait "${TEST_PREFIX}-reuse"

  run shell run "${TEST_PREFIX}-reuse" echo second

  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot prove"* ]]
  run zmx history "${TEST_PREFIX}-reuse"
  echo "$output" | grep -q "first"
  ! echo "$output" | grep -q "second"
}

@test "run on busy existing session errors with guidance" {
  shell run "${TEST_PREFIX}-busy" sleep 30
  sleep 0.5
  run shell run "${TEST_PREFIX}-busy" echo nope
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "busy\|running\|send"
}

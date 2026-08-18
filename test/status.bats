#!/usr/bin/env bats

load helpers

setup() {
  setup_zmx
  ATTACH_PID=""
}

teardown() {
  if [ -n "$ATTACH_PID" ] && kill -0 "$ATTACH_PID" 2>/dev/null; then
    kill "$ATTACH_PID" 2>/dev/null || true
    wait "$ATTACH_PID" 2>/dev/null || true
  fi
  teardown_zmx
}

wait_for_status() {
  local name="$1"
  local expression="$2"
  local observed

  for _ in $(seq 1 50); do
    if observed=$(shell status --json "$name") && printf '%s\n' "$observed" | jq -e "$expression" >/dev/null; then
      printf '%s\n' "$observed"
      return 0
    fi
    sleep 0.1
  done

  printf '%s\n' "${observed:-no status observed}" >&2
  return 1
}

@test "status shows running for active managed task" {
  shell run "${TEST_PREFIX}-stat" sleep 30
  run shell status --json "${TEST_PREFIX}-stat"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .status == "running"
    and .pty.status == "alive"
    and .last_task.status == "running"
  ' >/dev/null
}

@test "status shows an idle PTY separately from its exited last task" {
  shell run "${TEST_PREFIX}-done" echo done
  shell wait "${TEST_PREFIX}-done"

  run shell status "${TEST_PREFIX}-done"
  [ "$status" -eq 0 ]
  [[ "$output" == idle* ]]
  [[ "$output" == *"last task exited 0"* ]]

  run shell status --json "${TEST_PREFIX}-done"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .status == "idle"
    and .pty.status == "alive"
    and .foreground.status == "idle"
    and .last_task.status == "exited"
    and .last_task.exit_code == 0
    and .exit_code == 0
  ' >/dev/null
}

@test "status detects a reused foreground process before and after client attachment" {
  local name="${TEST_PREFIX}-reused"
  local ready="$BATS_TEST_TMPDIR/attach-ready"

  shell run "$name" echo initial-finished
  shell wait "$name"
  shell send "$name" 'sleep 30'

  wait_for_status "$name" '
    .status == "running"
    and .clients == 0
    and .pty.status == "alive"
    and .foreground.status == "running"
    and (.foreground.pid | type) == "number"
    and .last_task.status == "exited"
    and .last_task.exit_code == 0
  ' >/dev/null

  run shell run "$name" echo must-not-overlap
  [ "$status" -ne 0 ]
  [[ "$output" == *"not safely idle"* ]]

  python3 "$REPO_DIR/test/pty-attach-client.py" "$name" "$ready" &
  ATTACH_PID=$!
  wait_for_status "$name" '
    .status == "running"
    and .clients == 1
    and .foreground.status == "running"
    and .last_task.status == "exited"
  ' >/dev/null

  kill "$ATTACH_PID"
  wait "$ATTACH_PID"
  ATTACH_PID=""
  wait_for_status "$name" '
    .status == "running"
    and .clients == 0
    and .foreground.status == "running"
    and .last_task.status == "exited"
  ' >/dev/null

  printf '\003' | shell send --raw "$name"
  wait_for_status "$name" '
    .status == "idle"
    and .foreground.status == "idle"
    and .last_task.status == "exited"
  ' >/dev/null
}

@test "normalization preserves unknown when foreground state cannot be proven" {
  source "$REPO_DIR/lib/session-state.sh"

  run shell_normalize_session_json \
    '{"name":"stale","status":"exited (0)","pid":99999999,"clients":2,"exit_code":0}'
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .status == "unknown"
    and .pty.status == "alive"
    and .foreground.status == "unknown"
    and .clients == 2
    and .last_task.status == "exited"
  ' >/dev/null
}

@test "status exits 1 for nonexistent session" {
  run shell status "nonexistent-session-$$"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "not found"
}

@test "status --json escapes nonexistent session names" {
  run shell status --json 'bad"name'
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | head -n 1 | jq -e '.name == "bad\"name" and .status == "not found"' >/dev/null
}

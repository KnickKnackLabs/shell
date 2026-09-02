#!/usr/bin/env bats

load helpers

setup() {
  setup_zmx
  KEY_CASE_INDEX=0

  CAPTURE_SCRIPT="$BATS_TEST_TMPDIR/capture-key.py"
  cat >"$CAPTURE_SCRIPT" <<'PY'
import os
import sys
import tty

tty.setraw(sys.stdin.fileno())
print("capture-ready", flush=True)

wanted = int(sys.argv[1])
data = b""
while len(data) < wanted:
    data += os.read(sys.stdin.fileno(), wanted - len(data))

print("captured:" + data.hex(), flush=True)
PY
}

teardown() { teardown_zmx; }

wait_for_capture_ready() {
  local session="$1"
  local attempt

  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if zmx history "$session" 2>/dev/null | grep -q "capture-ready"; then
      return 0
    fi
    sleep 0.05
  done

  echo "capture process did not become ready" >&2
  return 1
}

assert_key_bytes() {
  local key="$1"
  local expected_hex="$2"
  local byte_count=$(( ${#expected_hex} / 2 ))
  local session

  KEY_CASE_INDEX=$((KEY_CASE_INDEX + 1))
  session="${TEST_PREFIX}-key-${KEY_CASE_INDEX}"

  shell run "$session" python3 -u "$CAPTURE_SCRIPT" "$byte_count"
  wait_for_capture_ready "$session"
  shell send-key "$session" "$key"
  shell wait "$session"

  run zmx history "$session"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "captured:${expected_hex}"
}

@test "send-key sends conventional terminal bytes for plain keys" {
  assert_key_bytes escape 1b
  assert_key_bytes enter 0d
  assert_key_bytes tab 09
  assert_key_bytes backspace 7f
}

@test "send-key sends conventional bytes for control keys" {
  assert_key_bytes ctrl+c 03
  assert_key_bytes ctrl+d 04
  assert_key_bytes ctrl+z 1a
}

@test "send-key sends Kitty CSI-u bytes for modified keys" {
  assert_key_bytes alt+enter 1b5b31333b3375
  assert_key_bytes alt+tab 1b5b393b3375
  assert_key_bytes super+enter 1b5b31333b3975
}

@test "send-key rejects unsupported key names" {
  run shell send-key "unused" space
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "unsupported key 'space'"
  echo "$output" | grep -q "Supported keys:"
}

@test "send-key errors on a nonexistent session" {
  run shell send-key "nonexistent-$$" escape
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

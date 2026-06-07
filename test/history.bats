#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "history shows command output" {
  shell run "${TEST_PREFIX}-hist" echo "history-marker-$$"
  sleep 0.5
  run shell history "${TEST_PREFIX}-hist"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "history-marker-$$"
}

@test "hyphenated running session resolves for status send and history" {
  local name="${TEST_PREFIX}-gitcrypt-workspaces"

  shell run "$name" cat
  sleep 0.5

  run shell status "$name"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "running"

  shell send "$name" "hyphenated-history-marker-$$"
  sleep 0.5

  run shell history "$name"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "hyphenated-history-marker-$$"
}

@test "history errors on nonexistent session" {
  run shell history "nonexistent-session-$$"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

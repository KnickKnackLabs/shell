#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "kill removes a running session" {
  shell run "${TEST_PREFIX}-killme" sleep 30
  run shell kill "${TEST_PREFIX}-killme"
  [ "$status" -eq 0 ]
  # Should no longer appear in list
  run zmx list --short
  ! echo "$output" | grep -q "${TEST_PREFIX}-killme"
}

@test "kill errors on nonexistent session" {
  run shell kill "nonexistent-session-$$"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

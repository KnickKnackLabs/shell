#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "wait returns after command finishes" {
  shell run "${TEST_PREFIX}-waiter" echo done
  run shell wait "${TEST_PREFIX}-waiter"
  [ "$status" -eq 0 ]
}

@test "wait errors on nonexistent session" {
  run shell wait "nonexistent-session-$$"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

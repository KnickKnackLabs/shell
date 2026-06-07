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

@test "history finds early short-list matches with many sessions" {
  shell run "${TEST_PREFIX}-aaa" echo "early-history-marker-$$"
  for i in $(seq 1 40); do
    shell run "${TEST_PREFIX}-zzz-$i" true
  done
  sleep 0.5

  run shell history "${TEST_PREFIX}-aaa"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "early-history-marker-$$"
}

@test "history errors on nonexistent session" {
  run shell history "nonexistent-session-$$"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

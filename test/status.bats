#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "status shows running for active session" {
  shell run "${TEST_PREFIX}-stat" sleep 30
  run shell status "${TEST_PREFIX}-stat"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "running"
}

@test "status shows exited after wait" {
  shell run "${TEST_PREFIX}-done" echo done
  # zmx only marks tasks as ended after `zmx wait` detects completion
  shell wait "${TEST_PREFIX}-done"
  run shell status "${TEST_PREFIX}-done"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "exited"
}

@test "status --json outputs valid JSON" {
  shell run "${TEST_PREFIX}-jstat" sleep 30
  run shell status --json "${TEST_PREFIX}-jstat"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d['status']=='running'"
}

@test "status exits 1 for nonexistent session" {
  run shell status "nonexistent-session-$$"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "not found"
}

#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "list succeeds with no active test sessions" {
  run shell list
  [ "$status" -eq 0 ]
}

@test "list shows a running session" {
  shell run "${TEST_PREFIX}-listed" sleep 30
  run shell list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${TEST_PREFIX}-listed"
}

@test "list --json outputs valid JSON array" {
  shell run "${TEST_PREFIX}-json" sleep 30
  run shell list --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, list)"
}

@test "list --json includes session name" {
  shell run "${TEST_PREFIX}-jname" sleep 30
  run shell list --json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert any(s['name']=='${TEST_PREFIX}-jname' for s in d)"
}

@test "list --json returns valid JSON with no sessions" {
  run shell list --json
  [ "$status" -eq 0 ]
  # Should be valid JSON (might contain sessions from other test files)
  echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert isinstance(d, list)"
}

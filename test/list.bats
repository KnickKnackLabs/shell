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
  echo "$output" | jq -e 'type == "array"' >/dev/null
}

@test "list --json includes session name" {
  shell run "${TEST_PREFIX}-jname" sleep 30
  run shell list --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg name "${TEST_PREFIX}-jname" 'any(.[]; .name == $name)' >/dev/null
}

@test "list --json preserves shell schema" {
  shell run "${TEST_PREFIX}-schema" sleep 30
  run shell list --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg name "${TEST_PREFIX}-schema" '
    .[]
    | select(.name == $name)
    | has("created") and has("ended") and (has("created_at") | not)
  ' >/dev/null
}

@test "list --json returns valid JSON with no sessions" {
  run shell list --json
  [ "$status" -eq 0 ]
  # Should be valid JSON (might contain sessions from other test files)
  echo "$output" | jq -e 'type == "array"' >/dev/null
}

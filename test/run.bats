#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "run launches a session and outputs the name" {
  run shell run "${TEST_PREFIX}-basic" echo hello
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${TEST_PREFIX}-basic"
}

@test "run session appears in shell list" {
  shell run "${TEST_PREFIX}-visible" sleep 30
  run shell list
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "${TEST_PREFIX}-visible"
}

@test "run rejects names starting with a dash" {
  run shell run "--bad-name" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "cannot start with a dash"
}

@test "run rejects invalid characters in name" {
  run shell run "bad name!" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "invalid session name"
}

@test "run fails without a command" {
  run shell run "${TEST_PREFIX}-nocmd"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "command\|arg"
}

@test "run fails if session already exists" {
  shell run "${TEST_PREFIX}-dup" sleep 30
  run shell run "${TEST_PREFIX}-dup" echo again
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "already exists"
}

@test "run executes the given command" {
  shell run "${TEST_PREFIX}-exec" echo "shell-test-marker"
  # Give it a moment to execute
  sleep 0.5
  run zmx history "${TEST_PREFIX}-exec"
  echo "$output" | grep -q "shell-test-marker"
}

@test "run --cwd sets working directory" {
  TESTDIR=$(mktemp -d)
  shell run "${TEST_PREFIX}-cwd" --cwd "$TESTDIR" pwd
  shell wait "${TEST_PREFIX}-cwd"
  run zmx history "${TEST_PREFIX}-cwd"
  echo "$output" | grep -q "$TESTDIR"
  rmdir "$TESTDIR"
}

@test "run --cwd errors on nonexistent directory" {
  run shell run "${TEST_PREFIX}-badcwd" --cwd "/tmp/nonexistent-$$" echo hello
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "not found"
}

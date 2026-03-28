#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

# --- basic send ---

@test "send delivers text to a running session" {
  # Start cat, which echoes stdin to stdout
  shell run "${TEST_PREFIX}-recv" cat
  sleep 0.5
  shell send "${TEST_PREFIX}-recv" "hello from send"
  sleep 0.5
  run zmx history "${TEST_PREFIX}-recv"
  echo "$output" | grep -q "hello from send"
}

@test "send errors on nonexistent session" {
  run shell send "nonexistent-$$" "hello"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no session"
}

@test "send errors with no input" {
  shell run "${TEST_PREFIX}-noinput" sleep 30
  run shell send "${TEST_PREFIX}-noinput"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "input\|message\|arg"
}

# --- shell run on existing sessions ---

@test "run on idle existing session sends a new command" {
  shell run "${TEST_PREFIX}-reuse" echo first
  shell wait "${TEST_PREFIX}-reuse"
  # Session is now idle (exited). Run again.
  shell run "${TEST_PREFIX}-reuse" echo second
  shell wait "${TEST_PREFIX}-reuse"
  run zmx history "${TEST_PREFIX}-reuse"
  echo "$output" | grep -q "first"
  echo "$output" | grep -q "second"
}

@test "run on busy existing session errors with guidance" {
  shell run "${TEST_PREFIX}-busy" sleep 30
  sleep 0.5
  run shell run "${TEST_PREFIX}-busy" echo nope
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "busy\|running\|send"
}

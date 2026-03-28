#!/usr/bin/env bats

load helpers

setup() { setup_zmx; }
teardown() { teardown_zmx; }

@test "env vars from caller are visible in the session" {
  export SHELL_TEST_MARKER="ikma-env-passthrough"
  shell run "${TEST_PREFIX}-env" printenv SHELL_TEST_MARKER
  shell wait "${TEST_PREFIX}-env"
  run zmx history "${TEST_PREFIX}-env"
  echo "$output" | grep -q "ikma-env-passthrough"
}

@test "multiple env vars pass through" {
  export SHELL_TEST_A="alpha"
  export SHELL_TEST_B="bravo"
  shell run "${TEST_PREFIX}-multi" bash -c 'printenv SHELL_TEST_A && printenv SHELL_TEST_B'
  shell wait "${TEST_PREFIX}-multi"
  run zmx history "${TEST_PREFIX}-multi"
  echo "$output" | grep -q "alpha"
  echo "$output" | grep -q "bravo"
}

@test "PATH is preserved in the session" {
  shell run "${TEST_PREFIX}-path" printenv PATH
  shell wait "${TEST_PREFIX}-path"
  run zmx history "${TEST_PREFIX}-path"
  # PATH should contain at least /usr/bin
  echo "$output" | grep -q "/usr/bin"
}

@test "env var with spaces passes through" {
  export SHELL_TEST_SPACES="hello world from ikma"
  shell run "${TEST_PREFIX}-spaces" printenv SHELL_TEST_SPACES
  shell wait "${TEST_PREFIX}-spaces"
  run zmx history "${TEST_PREFIX}-spaces"
  echo "$output" | grep -q "hello world from ikma"
}

@test "ZMX_SESSION is set inside the session" {
  shell run "${TEST_PREFIX}-zmxvar" printenv ZMX_SESSION
  shell wait "${TEST_PREFIX}-zmxvar"
  run zmx history "${TEST_PREFIX}-zmxvar"
  echo "$output" | grep -q "${TEST_PREFIX}-zmxvar"
}

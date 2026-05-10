# Shared test helpers for shell BATS tests
#
# Provides:
#   - shell() wrapper that calls tasks through mise
#   - Per-test zmx isolation via ZMX_DIR
#   - Robust teardown that kills zmx processes
#
# Tests should be invoked via `mise run test`; the helper resolves the repo
# from BATS_TEST_DIRNAME so tests do not depend on task-context env.

REPO_DIR="${BATS_TEST_DIRNAME%/test}"

# Skip all tests if zmx isn't available
if ! command -v zmx >/dev/null 2>&1; then
  skip "zmx not installed — skipping shell tests"
fi

# Prefix for test session names — kept short because zmx socket paths
# are limited to ~104 bytes on macOS (ZMX_DIR + name must fit).
TEST_PREFIX="st-$$"

# Isolate zmx per-test: each test gets its own socket directory.
# Uses /tmp directly (not BATS_TEST_TMPDIR) because Unix socket paths
# are limited to ~104 bytes on macOS.
setup_zmx() {
  ZMX_DIR=$(mktemp -d /tmp/sht.XXXXXX)
  export ZMX_DIR
  export TEST_PREFIX="st-${ZMX_DIR##*.}"
}

# Teardown: kill sessions via zmx, then clean up by PID as fallback.
teardown_zmx() {
  # Collect PIDs from zmx list before killing
  local pids=()
  while IFS= read -r line; do
    case "$line" in *pid=*)
      local pid
      pid=$(echo "$line" | tr '\t' '\n' | awk -F= '$1 == "pid" { print $2; exit }')
      [ -n "$pid" ] && pids+=("$pid")
    ;; esac
  done < <(zmx list 2>/dev/null || : ) # codebase:ignore or-true — cleanup should proceed if zmx is already unavailable

  # Graceful zmx kill
  local sessions
  sessions=$(zmx list --short 2>/dev/null || : ) # codebase:ignore or-true — cleanup should proceed if zmx is already unavailable
  while IFS= read -r name; do
    if [ -n "$name" ]; then
      zmx kill "$name" </dev/null >/dev/null 2>&1 || : # codebase:ignore or-true — best-effort cleanup
    fi
  done <<< "$sessions"

  sleep 0.1

  # Kill survivors by PID (and their children)
  for pid in "${pids[@]+"${pids[@]}"}"; do
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || : ) # codebase:ignore or-true — no children is expected
    for cpid in $children; do
      kill "$cpid" 2>/dev/null || : # codebase:ignore or-true — best-effort cleanup
    done
    kill "$pid" 2>/dev/null || : # codebase:ignore or-true — best-effort cleanup
  done

  rm -rf "${ZMX_DIR:-}"
}

shell() {
  mise -C "$REPO_DIR" run -q "$@"
}
export -f shell

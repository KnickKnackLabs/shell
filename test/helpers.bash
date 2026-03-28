# Shared test helpers for shell BATS tests
#
# Provides:
#   - shell() wrapper that calls tasks through mise
#   - Per-test zmx isolation via ZMX_DIR
#   - Robust teardown that kills zmx processes
#
# Tests must be invoked via `mise run test` — MISE_CONFIG_ROOT is required.

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "MISE_CONFIG_ROOT not set — run tests via: mise run test" >&2
  exit 1
fi

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
  export ZMX_DIR="/tmp/sht-$$"
  mkdir -p "$ZMX_DIR"
}

# Teardown: kill sessions via zmx, then clean up by PID as fallback.
teardown_zmx() {
  # Collect PIDs from zmx list before killing
  local pids=()
  while IFS= read -r line; do
    case "$line" in *pid=*)
      local pid
      pid=$(echo "$line" | tr '\t' '\n' | grep "^pid=" | cut -d= -f2 || true)
      [ -n "$pid" ] && pids+=("$pid")
    ;; esac
  done < <(zmx list 2>/dev/null || true)

  # Graceful zmx kill
  local sessions
  sessions=$(zmx list --short 2>/dev/null || true)
  while IFS= read -r name; do
    [ -n "$name" ] && zmx kill "$name" </dev/null >/dev/null 2>&1 || true
  done <<< "$sessions"

  sleep 0.1

  # Kill survivors by PID (and their children)
  for pid in "${pids[@]+"${pids[@]}"}"; do
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    for cpid in $children; do
      kill "$cpid" 2>/dev/null || true
    done
    kill "$pid" 2>/dev/null || true
  done

  rm -rf "${ZMX_DIR:-}"
}

shell() {
  mise -C "$MISE_CONFIG_ROOT" run -q "$@"
}
export -f shell

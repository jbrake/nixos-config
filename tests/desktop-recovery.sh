#!/usr/bin/env bash
# Failure injection runs only against temporary homes under fakeroot.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Match production realpath checks even when the runner's TMPDIR is a symlink.
test_root="$(realpath -e -- "$(mktemp -d)")"
trap 'rm -rf -- "$test_root"' EXIT
export REAL_CP REAL_MV
REAL_CP="$(command -v cp)"
REAL_MV="$(command -v mv)"
stub_bin="$test_root/bin"
mkdir "$stub_bin"
cat >"$stub_bin/cp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
last="${!#}"
if [[ ! -e "$TEST_FAILED" ]]; then
  if [[ "$TEST_FAILURE" == save && "$last" == *'/.plasma.new/'* ]]; then
    "$REAL_CP" "$@"
    touch "$TEST_FAILED"
    exit 42
  elif [[ "$TEST_FAILURE" == restore && "$last" == "$TEST_HOME/" ]]; then
    "$REAL_CP" "$@"
    printf 'partial\n' >"$TEST_HOME/.config/dconf/user"
    touch "$TEST_FAILED"
    exit 42
  fi
fi
exec "$REAL_CP" "$@"
STUB
cat >"$stub_bin/mv" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$TEST_FAILURE" == marker && "${!#}" == "$TEST_HOME/.local/state/desktop-profiles/current" && ! -e "$TEST_FAILED" ]]; then
  "$REAL_MV" "$@"
  touch "$TEST_FAILED"
  exit 42
fi
exec "$REAL_MV" "$@"
STUB
chmod +x "$stub_bin/"*

fail() { echo "FAIL: $*" >&2; exit 1; }
activate() {
  bash "$repo_root/scripts/desktop-state-activate.sh" "$1" "$TEST_HOME" 1000 100 >"$test_root/output" 2>&1
}
assert_state() {
  [[ "$(<"$state/current")" == "$1" ]] || fail "Incorrect marker for $TEST_FAILURE -> $1"
  [[ "$(<"$TEST_HOME/.config/dconf/user")" == "$1" ]] || fail "Incorrect restored data for $TEST_FAILURE -> $1"
  [[ "$(stat -c '%u:%g:%a' "$TEST_HOME")" == '1000:100:751' ]] || fail "Home metadata changed"
  [[ "$(<"$TEST_HOME/Documents/shared")" == shared ]] || fail "Shared data changed"
}

for TEST_FAILURE in save restore marker; do
  export TEST_FAILURE
  for destination in gnome plasma; do
    export TEST_HOME="$test_root/$TEST_FAILURE-$destination"
    export TEST_FAILED="$test_root/failed-$TEST_FAILURE-$destination"
    mkdir -p "$TEST_HOME/.config/dconf" "$TEST_HOME/Documents"
    chown 1000:100 "$TEST_HOME"
    chmod 751 "$TEST_HOME"
    printf 'shared\n' >"$TEST_HOME/Documents/shared"
    activate plasma
    printf 'plasma\n' >"$TEST_HOME/.config/dconf/user"
    activate gnome
    mkdir -p "$TEST_HOME/.config/dconf"
    printf 'gnome\n' >"$TEST_HOME/.config/dconf/user"
    activate plasma
    state="$TEST_HOME/.local/state/desktop-profiles"
    status=0
    PATH="$stub_bin:$PATH" activate gnome || status=$?
    [[ "$status" == 42 && -f "$TEST_FAILED" ]] || { cat "$test_root/output"; fail "Injection was not reached"; }
    if [[ "$TEST_FAILURE" == save ]]; then
      [[ ! -e "$state/pending" ]] || fail "Failed save marked transition pending"
      assert_state plasma
    else
      [[ -f "$state/pending" ]] || fail "Interrupted transition lost recovery marker"
      [[ "$(<"$state/plasma/.config/dconf/user")" == plasma ]] || fail "Source capsule damaged"
      [[ "$(<"$state/gnome/.config/dconf/user")" == gnome ]] || fail "Destination capsule damaged"
    fi
    activate "$destination"
    assert_state "$destination"
    [[ ! -e "$state/pending" ]] || fail "Recovery left pending marker"
    activate "$destination"
    assert_state "$destination"
  done
done

# An unresolved transition cannot be recovered by an unrelated third desktop.
printf 'plasma gnome\n' >"$state/pending"
if activate cosmic; then fail "Unrelated recovery target accepted"; fi
[[ -f "$state/pending" ]] || fail "Rejected recovery destroyed pending marker"
assert_state plasma

echo "Interrupted desktop saves, restores, marker updates, retries, and rollback passed"

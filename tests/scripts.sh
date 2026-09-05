#!/usr/bin/env bash
# Run through fakeroot: exercise ownership without real root or a real home.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Match production realpath checks even when the runner's TMPDIR is a symlink.
test_root="$(realpath -e -- "$(mktemp -d)")"
trap 'rm -rf -- "$test_root"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
[[ "$(id -u)" == 0 ]] || fail "Run with fakeroot -- bash tests/scripts.sh"

test_home="$test_root/home"
mkdir -p "$test_home/.config" "$test_home/Documents"
chown 1000:100 "$test_home"
chmod 751 "$test_home"
printf 'shared\n' >"$test_home/Documents/shared"

activate() {
  bash "$repo_root/scripts/desktop-state-activate.sh" "$1" "$test_home" 1000 100
  [[ "$(stat -c '%u:%g:%a' "$test_home")" == '1000:100:751' ]] || fail "Home metadata changed"
  [[ "$(<"$test_home/Documents/shared")" == shared ]] || fail "Shared data changed"
}

activate plasma
printf 'plasma\n' >"$test_home/.config/kdeglobals"
chown 1000:100 "$test_home/.config/kdeglobals"
chmod 640 "$test_home/.config/kdeglobals"
ln -s kdeglobals "$test_home/.config/kglobal-test-link"
activate gnome
[[ ! -e "$test_home/.config/kdeglobals" ]] || fail "Plasma state leaked into GNOME"
mkdir -p "$test_home/.config/dconf"
printf 'gnome\n' >"$test_home/.config/dconf/user"
activate plasma
[[ "$(<"$test_home/.config/kdeglobals")" == plasma ]] || fail "Plasma state was not restored"
[[ "$(stat -c '%u:%g:%a' "$test_home/.config/kdeglobals")" == '1000:100:640' ]] || fail "File metadata changed"
[[ "$(readlink "$test_home/.config/kglobal-test-link")" == kdeglobals ]] || fail "Symlink was not preserved"
[[ ! -e "$test_home/.config/dconf" ]] || fail "GNOME state leaked into Plasma"
activate gnome
[[ "$(<"$test_home/.config/dconf/user")" == gnome ]] || fail "GNOME state was not restored"

# Empty saved capsules must work too (nullglob must not pass a literal '*').
mkdir -m 700 "$test_home/.local/state/desktop-profiles/cosmic"
activate cosmic
activate cosmic
echo "Desktop state round trips and home metadata passed"

# Run the actual installer in a disposable checkout. Every command capable of
# installation is replaced with a stub; findmnt remains real for rejection tests.
fixture="$test_root/repo"
stub_bin="$test_root/bin"
mkdir -p "$fixture/scripts" "$fixture/hosts/test-host" "$stub_bin"
cp "$repo_root/scripts/install-host.sh" "$fixture/scripts/"
hardware="$fixture/hosts/test-host/hardware-configuration.nix"
printf 'original\n' >"$hardware"
export TEST_CALL_LOG="$test_root/calls"
cat >"$stub_bin/installer-command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name="${0##*/}"
printf '%s\n' "$name" >>"$TEST_CALL_LOG"
if [[ "$name" == nix ]]; then
  printf 'test-host'
  exit 0
fi
# Stop at hardware generation: no real installation is ever attempted.
exit 97
EOF
chmod +x "$stub_bin/installer-command"
for command in nix nixos-generate-config nixos-install nixos-enter; do
  ln -s installer-command "$stub_bin/$command"
done

reject_target() {
  local target="$1" message="$2"
  : >"$TEST_CALL_LOG"
  if PATH="$stub_bin:$PATH" bash "$fixture/scripts/install-host.sh" test-host "$target" >"$test_root/output" 2>&1; then
    fail "Installer accepted $target"
  fi
  grep -q "$message" "$test_root/output" || { cat "$test_root/output"; fail "Wrong rejection"; }
  [[ ! -s "$TEST_CALL_LOG" ]] || fail "Installer performed work before rejecting target"
  [[ "$(<"$hardware")" == original ]] || fail "Installer replaced hardware config"
}

ordinary="$test_root/unmounted"
mkdir "$ordinary"
reject_target "$ordinary" 'not a mount point'
reject_target / 'unsafe installation root'
ln -s / "$test_root/root-link"
reject_target "$test_root/root-link" 'unsafe installation root'
reject_target relative 'existing absolute directory'
reject_target "$test_root/missing" 'existing absolute directory'

# Simulate an exact mount for the existing-checkout and successful-preflight
# branches without needing CAP_SYS_ADMIN or mounting a host disk.
export TEST_MOUNT="$test_root/mounted"
mkdir "$TEST_MOUNT"
cat >"$stub_bin/findmnt" <<'EOF'
#!/usr/bin/env bash
[[ $# == 2 && "$1" == --mountpoint && "$2" == "$TEST_MOUNT" ]]
EOF
chmod +x "$stub_bin/findmnt"
target_repo="$TEST_MOUNT/home/jason/Documents/repos/nixos-config"
mkdir -p "$target_repo"
reject_target "$TEST_MOUNT" 'existing target'
rmdir "$target_repo"
ln -s "$test_root/absent" "$target_repo"
reject_target "$TEST_MOUNT" 'existing target'
rm "$target_repo"

: >"$TEST_CALL_LOG"
status=0
PATH="$stub_bin:$PATH" bash "$fixture/scripts/install-host.sh" test-host "$TEST_MOUNT" >"$test_root/output" 2>&1 || status=$?
[[ "$status" == 97 ]] || { cat "$test_root/output"; fail "Valid target failed preflight"; }
[[ "$(cat "$TEST_CALL_LOG")" == $'nix\nnixos-generate-config' ]] || fail "Unexpected installation commands"
echo "Installer preflight passed"

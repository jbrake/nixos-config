#!/usr/bin/env bash
# Exercise update transactions without network calls, real builds, or sudo.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
fixture="$test_root/repo"
stub_bin="$test_root/bin"
mkdir -p "$fixture/scripts" "$fixture/packages" "$fixture/hosts/test-host" "$stub_bin"
cp "$repo_root/scripts/"{update-system,update-tone3000,desktop-profile-guard}.sh "$fixture/scripts/"
touch "$fixture/hosts/test-host/hardware-configuration.nix"
export TEST_CALL_LOG="$test_root/calls"

cat >"$stub_bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "nix $*" >>"$TEST_CALL_LOG"
case "$1" in
  eval) printf 'test-host' ;;
  flake)
    [[ "$2" == update ]] || exit 99
    printf 'new-lock\n' >flake.lock
    [[ "$TEST_FAIL_STAGE" != update ]]
    ;;
  develop)
    [[ "$*" == *'--no-update-lock-file --command nix-update tone3000'* ]] || exit 99
    printf 'new-package\n' >packages/tone3000.nix
    [[ "$TEST_FAIL_STAGE" != update ]]
    ;;
  build) [[ "$TEST_FAIL_STAGE" != build ]] ;;
  *) exit 99 ;;
esac
EOF
cat >"$stub_bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "sudo $*" >>"$TEST_CALL_LOG"
[[ "$TEST_FAIL_STAGE" != activation ]]
EOF
cat >"$stub_bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'test-host\n'
EOF
chmod +x "$stub_bin/"*

fail() { cat "$test_root/output" >&2; echo "FAIL: $*" >&2; exit 1; }

run_case() {
  local script="$1" stage="$2" status=0
  printf 'old-lock\n' >"$fixture/flake.lock"
  printf 'old-package\n' >"$fixture/packages/tone3000.nix"
  : >"$TEST_CALL_LOG"
  export TEST_FAIL_STAGE="$stage"
  local args=()
  [[ "$script" != update-system ]] || args=(test-host)
  PATH="$stub_bin:$PATH" bash "$fixture/scripts/$script.sh" "${args[@]}" >"$test_root/output" 2>&1 || status=$?
  if [[ "$stage" == success ]]; then
    [[ $status == 0 ]] || fail "$script failed on success path"
  else
    [[ $status != 0 ]] || fail "$script ignored $stage failure"
  fi

  if [[ "$script" == update-system ]]; then
    [[ "$(<"$fixture/packages/tone3000.nix")" == old-package ]] || fail "System update touched TONE3000"
    ! grep -q 'nix develop' "$TEST_CALL_LOG" || fail "System update invoked package updater"
    if [[ "$stage" == success || "$stage" == activation ]]; then
      [[ "$(<"$fixture/flake.lock")" == new-lock ]] || fail "Successful build's lock was lost"
      grep -q '^sudo nixos-rebuild switch' "$TEST_CALL_LOG" || fail "Successful build was not activated"
    else
      [[ "$(<"$fixture/flake.lock")" == old-lock ]] || fail "Lock was not restored"
      ! grep -q '^sudo ' "$TEST_CALL_LOG" || fail "Failed update was activated"
    fi
  else
    [[ "$(<"$fixture/flake.lock")" == old-lock ]] || fail "Package update touched flake.lock"
    ! grep -q '^sudo ' "$TEST_CALL_LOG" || fail "Package update activated a system"
    if [[ "$stage" == success ]]; then
      [[ "$(<"$fixture/packages/tone3000.nix")" == new-package ]] || fail "Package update was lost"
      grep -q '#tone3000 --no-link --no-update-lock-file' "$TEST_CALL_LOG" || fail "Package was not built"
    else
      [[ "$(<"$fixture/packages/tone3000.nix")" == old-package ]] || fail "Package was not restored"
    fi
  fi
}

for stage in success update build activation; do
  run_case update-system "$stage"
done
for stage in success update build; do
  run_case update-tone3000 "$stage"
done
echo "Independent system/package updates and failure recovery passed"

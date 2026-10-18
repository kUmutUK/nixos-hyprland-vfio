#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

HELPERS="$TMP_DIR/rollback-functions.sh"
: > "$HELPERS"
for function_name in assert_no_symlink_transaction_targets transaction_backup_path rollback_deployment; do
  awk -v wanted="${function_name}() {" '
    $0 == wanted { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$INSTALLER" >> "$HELPERS"
done
if ! grep -q '^assert_no_symlink_transaction_targets() {' "$HELPERS" \
  || ! grep -q '^transaction_backup_path() {' "$HELPERS" \
  || ! grep -q '^rollback_deployment() {' "$HELPERS"; then
  fail 'could not extract the installer transaction helpers'
fi

TEST_ROOT="$TMP_DIR/system"
NIXOS_FLAKE_DIR="$TEST_ROOT/etc/nixos/nixos"
PATCHED_XML="$TEST_ROOT/var/lib/libvirt/win10.xml"
BACKUP_DIR="$TMP_DIR/backup"
SYMLINK_TARGET="$NIXOS_FLAKE_DIR/symlink-config.nix"
SYMLINK_REFERENT="$TEST_ROOT/original-referent.conf"
DANGLING_TARGET="$NIXOS_FLAKE_DIR/dangling-config.nix"
DANGLING_REFERENT="$TEST_ROOT/missing-original.conf"
mkdir -p "$NIXOS_FLAKE_DIR/hooks" "$(dirname "$PATCHED_XML")" "$BACKUP_DIR"
printf 'original configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'original hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'original vm xml\n' > "$PATCHED_XML"
printf 'original symlink referent\n' > "$SYMLINK_REFERENT"
ln -s "$SYMLINK_REFERENT" "$SYMLINK_TARGET"
ln -s "$DANGLING_REFERENT" "$DANGLING_TARGET"

# The installer must fail closed for active and dangling symlinks at deployment
# targets instead of silently replacing a link or writing through it.
PREFLIGHT_HELPER="$TMP_DIR/symlink-preflight.sh"
awk '$0 == "assert_no_symlink_transaction_targets() {" { capture = 1 } capture { print } capture && /^}/ { exit }' "$INSTALLER" > "$PREFLIGHT_HELPER"
cat > "$TMP_DIR/preflight-harness.sh" <<'BASH'
set -euo pipefail
NIXOS_FLAKE_DIR="$1"
TRANSACTION_PATHS=("$2")
error() { printf '%s\n' "$*" >&2; return 0; }
source "$3"
assert_no_symlink_transaction_targets
BASH
run_preflight_check() {
  local expected="$1" directory="$2" target="$3" status=0
  if bash "$TMP_DIR/preflight-harness.sh" "$directory" "$target" "$PREFLIGHT_HELPER" >/dev/null 2>&1; then
    status=0
  else
    status=$?
  fi
  [[ "$status" -eq "$expected" ]] || fail "symlink preflight returned $status for $target (expected $expected)"
}
printf 'normal target\n' > "$NIXOS_FLAKE_DIR/normal-config.nix"
run_preflight_check 0 "$NIXOS_FLAKE_DIR" "$NIXOS_FLAKE_DIR/normal-config.nix"
run_preflight_check 1 "$NIXOS_FLAKE_DIR" "$SYMLINK_TARGET"
run_preflight_check 1 "$NIXOS_FLAKE_DIR" "$DANGLING_TARGET"
SYMLINK_DIRECTORY="$TEST_ROOT/etc/nixos/nixos-link"
ln -s "$NIXOS_FLAKE_DIR" "$SYMLINK_DIRECTORY"
run_preflight_check 1 "$SYMLINK_DIRECTORY" "$NIXOS_FLAKE_DIR/normal-config.nix"

# Use the same flattened backup naming convention as install.sh and preserve links.
for target in "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/hooks" "$PATCHED_XML" "$SYMLINK_TARGET" "$DANGLING_TARGET"; do
  backup_name="$(printf '%s' "$target" | tr '/' '_')"
  cp -a -- "$target" "$BACKUP_DIR/$backup_name"
done

# Simulate a partially completed deployment: some existing files have been
# overwritten and targets that were previously absent have been created.
printf 'partially deployed configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'partially deployed hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'new home config\n' > "$NIXOS_FLAKE_DIR/home.nix"
printf 'partially deployed xml\n' > "$PATCHED_XML"
rm -- "$SYMLINK_TARGET" "$DANGLING_TARGET"
ln -s "$TEST_ROOT/changed-referent.conf" "$SYMLINK_TARGET"
ln -s "$TEST_ROOT/missing-changed.conf" "$DANGLING_TARGET"

set +e
(
  set -euo pipefail
  BACKUP_DIR="$BACKUP_DIR"
  NIXOS_FLAKE_DIR="$NIXOS_FLAKE_DIR"
  PATCHED_XML="$PATCHED_XML"
  TRANSACTION_PATHS=(
    "$NIXOS_FLAKE_DIR/configuration.nix"
    "$NIXOS_FLAKE_DIR/home.nix"
    "$NIXOS_FLAKE_DIR/flake.nix"
    "$NIXOS_FLAKE_DIR/flake.lock"
    "$NIXOS_FLAKE_DIR/hooks"
    "$NIXOS_FLAKE_DIR/hardware-configuration.nix"
    "$PATCHED_XML"
    "$SYMLINK_TARGET"
    "$DANGLING_TARGET"
  )
  declare -A TRANSACTION_EXISTED=()
  for target in "${TRANSACTION_PATHS[@]}"; do
    case "$target" in
      "$NIXOS_FLAKE_DIR/configuration.nix"|"$NIXOS_FLAKE_DIR/hooks"|"$PATCHED_XML"|"$SYMLINK_TARGET"|"$DANGLING_TARGET") TRANSACTION_EXISTED["$target"]=1 ;;
      *)
        # shellcheck disable=SC2034 # consumed by sourced installer helpers
        TRANSACTION_EXISTED["$target"]=0
        ;;
    esac
  done
  # shellcheck disable=SC2034 # consumed by sourced installer helpers
  TRANSACTION_ACTIVE=1
  sudo() {
    if [[ "$1" == chown ]]; then return 0; fi
    "$@"
  }
  warn() { :; }
  # shellcheck disable=SC1090 # HELPERS is computed at runtime
  source "$HELPERS"
  rollback_deployment 1
)
rollback_status=$?
set -e
[[ "$rollback_status" -eq 1 ]] || fail "rollback should preserve the original failure status 1 (got $rollback_status)"

[[ "$(cat "$NIXOS_FLAKE_DIR/configuration.nix")" == 'original configuration' ]] \
  || fail 'existing configuration.nix was not restored from backup'
[[ "$(cat "$NIXOS_FLAKE_DIR/hooks/qemu")" == 'original hook' ]] \
  || fail 'existing hooks directory was not restored from backup'
[[ "$(cat "$PATCHED_XML")" == 'original vm xml' ]] \
  || fail 'existing VM XML was not restored from backup'
[[ ! -e "$NIXOS_FLAKE_DIR/home.nix" ]] \
  || fail 'newly created home.nix was not removed during rollback'
[[ ! -e "$NIXOS_FLAKE_DIR/flake.nix" ]] \
  || fail 'newly created flake.nix was not removed during rollback'
[[ -L "$SYMLINK_TARGET" ]] || fail 'rollback did not restore the active symbolic link itself'
[[ "$(readlink "$SYMLINK_TARGET")" == "$SYMLINK_REFERENT" ]] \
  || fail 'rollback changed the active symbolic link target'
[[ "$(cat "$SYMLINK_REFERENT")" == 'original symlink referent' ]] \
  || fail 'rollback damaged the active symbolic link referent'
[[ -L "$DANGLING_TARGET" ]] || fail 'rollback did not restore the dangling symbolic link itself'
[[ "$(readlink "$DANGLING_TARGET")" == "$DANGLING_REFERENT" ]] \
  || fail 'rollback changed the dangling symbolic link target'

printf 'OK: installer rollback restores files, active/dangling symlinks, and removes new targets.\n'

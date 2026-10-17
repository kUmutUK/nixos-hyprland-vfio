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
for function_name in transaction_backup_path rollback_deployment; do
  awk -v wanted="${function_name}() {" '
    $0 == wanted { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$INSTALLER" >> "$HELPERS"
done
if ! grep -q '^transaction_backup_path() {' "$HELPERS" || ! grep -q '^rollback_deployment() {' "$HELPERS"; then
  fail 'could not extract the installer transaction helpers'
fi

TEST_ROOT="$TMP_DIR/system"
NIXOS_FLAKE_DIR="$TEST_ROOT/etc/nixos/nixos"
PATCHED_XML="$TEST_ROOT/var/lib/libvirt/win10.xml"
BACKUP_DIR="$TMP_DIR/backup"
mkdir -p "$NIXOS_FLAKE_DIR/hooks" "$(dirname "$PATCHED_XML")" "$BACKUP_DIR"
printf 'original configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'original hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'original vm xml\n' > "$PATCHED_XML"

# Use the same flattened backup naming convention as install.sh.
for target in "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/hooks" "$PATCHED_XML"; do
  backup_name="$(printf '%s' "$target" | tr '/' '_')"
  cp -a -- "$target" "$BACKUP_DIR/$backup_name"
done

# Simulate a partially completed deployment: some existing files have been
# overwritten and targets that were previously absent have been created.
printf 'partially deployed configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'partially deployed hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'new home config\n' > "$NIXOS_FLAKE_DIR/home.nix"
printf 'partially deployed xml\n' > "$PATCHED_XML"

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
  )
  declare -A TRANSACTION_EXISTED=()
  for target in "${TRANSACTION_PATHS[@]}"; do
    case "$target" in
      "$NIXOS_FLAKE_DIR/configuration.nix"|"$NIXOS_FLAKE_DIR/hooks"|"$PATCHED_XML") TRANSACTION_EXISTED["$target"]=1 ;;
      *) TRANSACTION_EXISTED["$target"]=0 ;;
    esac
  done
  TRANSACTION_ACTIVE=1
  sudo() {
    if [[ "$1" == chown ]]; then return 0; fi
    "$@"
  }
  warn() { :; }
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

printf 'OK: installer rollback restores previous files and removes newly created targets.\n'

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
SOURCE_REVISION_FILE="$TEST_ROOT/etc/nixos/.source-revision"
BACKUP_DIR="$TMP_DIR/backup"
SYMLINK_TARGET="$NIXOS_FLAKE_DIR/symlink-config.nix"
SYMLINK_REFERENT="$TEST_ROOT/original-referent.conf"
DANGLING_TARGET="$NIXOS_FLAKE_DIR/dangling-config.nix"
DANGLING_REFERENT="$TEST_ROOT/missing-original.conf"
mkdir -p "$NIXOS_FLAKE_DIR/hooks" "$(dirname "$PATCHED_XML")" "$(dirname "$SOURCE_REVISION_FILE")" "$BACKUP_DIR"
printf 'original configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'original LSFG package expression\n' > "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"
printf 'original hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'original vm xml\n' > "$PATCHED_XML"
printf 'original source revision\n' > "$SOURCE_REVISION_FILE"
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
for target in "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix" "$NIXOS_FLAKE_DIR/hooks" "$SOURCE_REVISION_FILE" "$PATCHED_XML" "$SYMLINK_TARGET" "$DANGLING_TARGET"; do
  backup_name="$(printf '%s' "$target" | tr '/' '_')"
  cp -a -- "$target" "$BACKUP_DIR/$backup_name"
done

# Simulate a partially completed deployment: some existing files have been
# overwritten and targets that were previously absent have been created.
printf 'partially deployed configuration\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'partially deployed LSFG package expression\n' > "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"
printf 'partially deployed hook\n' > "$NIXOS_FLAKE_DIR/hooks/qemu"
printf 'new source revision\n' > "$SOURCE_REVISION_FILE"
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
    "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"
    "$NIXOS_FLAKE_DIR/hooks"
    "$NIXOS_FLAKE_DIR/hardware-configuration.nix"
    "$SOURCE_REVISION_FILE"
    "$PATCHED_XML"
    "$SYMLINK_TARGET"
    "$DANGLING_TARGET"
  )
  declare -A TRANSACTION_EXISTED=()
  for target in "${TRANSACTION_PATHS[@]}"; do
    case "$target" in
      "$NIXOS_FLAKE_DIR/configuration.nix"|"$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"|"$NIXOS_FLAKE_DIR/hooks"|"$SOURCE_REVISION_FILE"|"$PATCHED_XML"|"$SYMLINK_TARGET"|"$DANGLING_TARGET") TRANSACTION_EXISTED["$target"]=1 ;;
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
[[ "$(cat "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix")" == 'original LSFG package expression' ]] \
  || fail 'existing lsfg-vk-v2.nix was not restored from backup'
[[ "$(cat "$NIXOS_FLAKE_DIR/hooks/qemu")" == 'original hook' ]] \
  || fail 'existing hooks directory was not restored from backup'
[[ "$(cat "$PATCHED_XML")" == 'original vm xml' ]] \
  || fail 'existing VM XML was not restored from backup'
[[ "$(cat "$SOURCE_REVISION_FILE")" == 'original source revision' ]] \
  || fail 'previous .source-revision marker was not restored from backup'
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

# When /etc/nixos/nixos did not exist before installation, rollback should remove
# the new directory only after deleting managed targets and only if it is empty.
NEW_DIR_HARNESS="$TMP_DIR/new-directory-rollback-harness.sh"
cat > "$NEW_DIR_HARNESS" <<'BASH'
set -euo pipefail
NIXOS_FLAKE_DIR="$1"
BACKUP_DIR="$2"
HELPERS="$3"
PATCHED_XML="$4"
KEEP_EXTRA="$5"
TRANSACTION_PATHS=(
  "$NIXOS_FLAKE_DIR/configuration.nix"
  "$NIXOS_FLAKE_DIR/home.nix"
  "$NIXOS_FLAKE_DIR/flake.nix"
  "$NIXOS_FLAKE_DIR/flake.lock"
  "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"
  "$NIXOS_FLAKE_DIR/hooks"
  "$NIXOS_FLAKE_DIR/hardware-configuration.nix"
  "$PATCHED_XML"
)
declare -A TRANSACTION_EXISTED=()
for target in "${TRANSACTION_PATHS[@]}"; do
  TRANSACTION_EXISTED["$target"]=0
done
NIXOS_FLAKE_DIR_EXISTED=0
TRANSACTION_ACTIVE=1
mkdir -p "$NIXOS_FLAKE_DIR/hooks"
printf 'created by failed installer\n' > "$NIXOS_FLAKE_DIR/configuration.nix"
printf 'new LSFG package expression\n' > "$NIXOS_FLAKE_DIR/lsfg-vk-v2.nix"
if [[ "$KEEP_EXTRA" == "yes" ]]; then
  printf 'preserve unrelated content\n' > "$NIXOS_FLAKE_DIR/user-notes.txt"
fi
sudo() {
  if [[ "$1" == chown ]]; then return 0; fi
  "$@"
}
warn() { printf '%s\n' "$*" >&2; }
source "$HELPERS"
rollback_deployment 1
BASH

NEW_FLAKE_DIR="$TEST_ROOT/etc/nixos/new-nixos-flake"
NEW_XML="$TEST_ROOT/var/lib/libvirt/new-win10.xml"
set +e
bash "$NEW_DIR_HARNESS" "$NEW_FLAKE_DIR" "$BACKUP_DIR" "$HELPERS" "$NEW_XML" no >/dev/null 2>&1
new_dir_status=$?
set -e
[[ "$new_dir_status" -eq 1 ]] || fail "new-directory rollback should preserve original exit status 1 (got $new_dir_status)"
[[ ! -e "$NEW_FLAKE_DIR" ]] || fail 'rollback left the empty deployment directory created by this run'
printf 'OK: rollback removes an empty deployment directory created by the failed run.\n'

NEW_FLAKE_DIR_WITH_EXTRA="$TEST_ROOT/etc/nixos/new-nixos-flake-with-extra"
set +e
bash "$NEW_DIR_HARNESS" "$NEW_FLAKE_DIR_WITH_EXTRA" "$BACKUP_DIR" "$HELPERS" "$NEW_XML" yes >/dev/null 2>&1
new_dir_extra_status=$?
set -e
[[ "$new_dir_extra_status" -eq 1 ]] || fail "nonempty-directory rollback should preserve original exit status 1 (got $new_dir_extra_status)"
[[ -f "$NEW_FLAKE_DIR_WITH_EXTRA/user-notes.txt" ]] || fail 'rollback removed unrelated content from the new deployment directory'
printf 'OK: rollback retains a newly created deployment directory when unrelated content remains.\n'

# Snapshot cleanup is part of rollback only if this run created the subvolume.
# Empty subvolumes may be removed; nonempty ones must be retained for safety.
SNAPSHOT_HARNESS="$TMP_DIR/snapshot-rollback-harness.sh"
cat > "$SNAPSHOT_HARNESS" <<'BASH'
set -euo pipefail
SNAPSHOT_SUBVOL="$1"
BACKUP_DIR="$2"
HELPERS="$3"
TRANSACTION_PATHS=()
declare -A TRANSACTION_EXISTED=()
TRANSACTION_ACTIVE=1
SNAPSHOT_SUBVOL_CREATED=1
warn() { printf '%s\n' "$*" >&2; }
sudo() {
  if [[ "$1" == btrfs && "$2" == subvolume && "$3" == show ]]; then
    [[ -d "$4" ]]
  elif [[ "$1" == btrfs && "$2" == subvolume && "$3" == delete ]]; then
    rm -rf -- "$4"
  elif [[ "$1" == find ]]; then
    shift
    command find "$@"
  elif [[ "$1" == chown ]]; then
    return 0
  else
    command "$@"
  fi
}
source "$HELPERS"
rollback_deployment 1
BASH

EMPTY_SNAPSHOT="$TMP_DIR/new-empty-snapshot"
mkdir -p "$EMPTY_SNAPSHOT"
set +e
bash "$SNAPSHOT_HARNESS" "$EMPTY_SNAPSHOT" "$BACKUP_DIR" "$HELPERS" >/dev/null 2>&1
empty_snapshot_status=$?
set -e
[[ "$empty_snapshot_status" -eq 1 ]] || fail "snapshot rollback did not preserve original exit status for an empty subvolume"
[[ ! -e "$EMPTY_SNAPSHOT" ]] || fail 'rollback did not remove the empty snapshot subvolume created in this run'

NONEMPTY_SNAPSHOT="$TMP_DIR/new-nonempty-snapshot"
mkdir -p "$NONEMPTY_SNAPSHOT"
printf 'keep me\n' > "$NONEMPTY_SNAPSHOT/user-data"
set +e
bash "$SNAPSHOT_HARNESS" "$NONEMPTY_SNAPSHOT" "$BACKUP_DIR" "$HELPERS" >/dev/null 2>&1
nonempty_snapshot_status=$?
set -e
[[ "$nonempty_snapshot_status" -eq 1 ]] || fail "snapshot rollback did not preserve original exit status for a nonempty subvolume"
[[ -f "$NONEMPTY_SNAPSHOT/user-data" ]] || fail 'rollback removed data from a nonempty snapshot subvolume'
printf 'OK: installer rollback removes only a newly-created empty snapshot subvolume and retains nonempty content.\n'

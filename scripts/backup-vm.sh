#!/usr/bin/env bash
# VM disk backup: create a compressed, integrity-checked copy of the Windows
# guest's qcow2 disk while the VM is guaranteed to be shut off.
#
# Fail-closed rules, matching the repository's installer discipline:
#   1. Refuse to run unless `virsh domstate` reports exactly "shut off".
#   2. Refuse to overwrite an existing destination file or leftover .part.
#   3. Write to "<destination>.part" first; only an atomic rename publishes
#      the backup, so an interrupted run never replaces a good archive.
#   4. Run qemu-img check before publishing and write a SHA-256 sidecar.
#   5. Verify the sidecar, then prune only older backups whose sidecars verify.
#
# The backup target must be an existing, writable directory; a mounted
# external disk is recommended. The media partition that stores the live disk
# is not a backup target. This script never writes to the source disk and
# never starts, stops, or otherwise touches the VM.
#
# Usage: scripts/backup-vm.sh <destination-directory> [source-disk]
#   <destination-directory>  required; must already exist and be writable.
#   [source-disk]            defaults to /mnt/media/win10new.qcow2 (the
#                            win10.xml vda path).
# Environment overrides: BACKUP_VM_NAME (default: win10),
#   BACKUP_RETENTION_COUNT (default: 4; allowed range: 1..52).
set -euo pipefail

usage() {
  sed -n 's/^# \?//p' "$0" | sed -n '/^Usage:/,/^$/p' | head -n 4
  exit 2
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

DEST_DIR="${1-}"
SOURCE_DISK="${2-/mnt/media/win10new.qcow2}"
VM_NAME="${BACKUP_VM_NAME:-win10}"

[ -n "$DEST_DIR" ] || usage
command -v virsh >/dev/null 2>&1 || fail "virsh not found in PATH"
command -v qemu-img >/dev/null 2>&1 || fail "qemu-img not found in PATH"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum not found in PATH"
command -v find >/dev/null 2>&1 || fail "find not found in PATH"
command -v sort >/dev/null 2>&1 || fail "sort not found in PATH"
command -v rm >/dev/null 2>&1 || fail "rm not found in PATH"
[[ "$VM_NAME" =~ ^[A-Za-z0-9._-]+$ ]] || fail "BACKUP_VM_NAME contains unsupported characters"
[ -f "$SOURCE_DISK" ] || fail "source disk image not found: $SOURCE_DISK"
[ -d "$DEST_DIR" ] || fail "destination directory not found: $DEST_DIR"
[ -w "$DEST_DIR" ] || fail "destination directory not writable: $DEST_DIR"

RETENTION="${BACKUP_RETENTION_COUNT:-4}"
if [[ ! "$RETENTION" =~ ^[0-9]+$ ]] || (( RETENTION < 1 || RETENTION > 52 )); then
  fail "BACKUP_RETENTION_COUNT must be an integer from 1 to 52"
fi

STATE="$(virsh domstate "$VM_NAME" 2>/dev/null || true)"
if [ "$STATE" != "shut off" ]; then
  fail "VM '$VM_NAME' is not shut off (state: ${STATE:-unknown}); refusing to back up a live disk"
fi

STAMP="$(date +%F)"
FINAL_PATH="$DEST_DIR/${VM_NAME}-${STAMP}.qcow2"
PART_PATH="${FINAL_PATH}.part"
CHECKSUM_PATH="${FINAL_PATH}.sha256"
CHECKSUM_PART="${CHECKSUM_PATH}.part"

[ -e "$FINAL_PATH" ] && fail "destination already exists: $FINAL_PATH (remove it first or pick another directory)"
[ -e "$PART_PATH" ] && fail "incomplete backup left over from a previous run: $PART_PATH (remove it first)"
[ -e "$CHECKSUM_PATH" ] && fail "checksum sidecar already exists: $CHECKSUM_PATH"
[ -e "$CHECKSUM_PART" ] && fail "incomplete checksum sidecar exists: $CHECKSUM_PART"

# The guest was confirmed shut off above. Convert only to a temporary file,
# validate its qcow2 structure, and publish only after it passes qemu-img check.
qemu-img convert -c -O qcow2 "$SOURCE_DISK" "$PART_PATH"
qemu-img check "$PART_PATH"
DIGEST="$(sha256sum "$PART_PATH" | awk '{print $1}')"
printf '%s  %s\n' "$DIGEST" "$(basename "$FINAL_PATH")" > "$CHECKSUM_PART"
mv -- "$PART_PATH" "$FINAL_PATH"
mv -- "$CHECKSUM_PART" "$CHECKSUM_PATH"

(
  cd "$DEST_DIR"
  sha256sum -c "$(basename "$CHECKSUM_PATH")"
) || fail "published backup failed SHA-256 verification: $FINAL_PATH"

# Retain the newest configured number of backups only when both the qcow2
# file and its SHA-256 sidecar verify. Unknown/incomplete files are preserved.
mapfile -t BACKUPS < <(
  find "$DEST_DIR" -maxdepth 1 -type f -name "${VM_NAME}-????-??-??.qcow2" -printf '%f\n' | sort -r
)
VERIFIED_COUNT=0
for OLD_NAME in "${BACKUPS[@]}"; do
  [[ "$OLD_NAME" =~ ^${VM_NAME}-[0-9]{4}-[0-9]{2}-[0-9]{2}\.qcow2$ ]] || continue
  OLD_SUM="$OLD_NAME.sha256"
  [[ -f "$DEST_DIR/$OLD_SUM" ]] || continue
  if (cd "$DEST_DIR" && sha256sum -c "$OLD_SUM" >/dev/null 2>&1); then
    VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
    if (( VERIFIED_COUNT > RETENTION )); then
      rm -- "$DEST_DIR/$OLD_NAME" "$DEST_DIR/$OLD_SUM"
    fi
  fi
done

printf 'backup OK: %s\nSHA-256: %s\nRetention: %s verified backup(s)\n' "$FINAL_PATH" "$DIGEST" "$RETENTION"

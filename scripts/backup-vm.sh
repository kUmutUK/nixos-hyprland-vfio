#!/usr/bin/env bash
# VM disk backup: create a compressed, integrity-checked copy of the Windows
# guest's qcow2 disk while the VM is guaranteed to be shut off.
#
# Fail-closed rules, matching the repository's installer discipline:
#   1. Refuse to run unless `virsh domstate` reports exactly "shut off".
#   2. Refuse to overwrite an existing destination file or leftover .part.
#   3. Write to "<destination>.part" first; only an atomic rename publishes
#      the backup, so an interrupted run never replaces a good archive.
#   4. Print the SHA-256 of the published file so the archive can later be
#      verified against the recorded digest.
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
# Environment overrides: BACKUP_VM_NAME (default: win10).
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
[ -f "$SOURCE_DISK" ] || fail "source disk image not found: $SOURCE_DISK"
[ -d "$DEST_DIR" ] || fail "destination directory not found: $DEST_DIR"
[ -w "$DEST_DIR" ] || fail "destination directory not writable: $DEST_DIR"

STATE="$(virsh domstate "$VM_NAME" 2>/dev/null || true)"
if [ "$STATE" != "shut off" ]; then
  fail "VM '$VM_NAME' is not shut off (state: ${STATE:-unknown}); refusing to back up a live disk"
fi

STAMP="$(date +%F)"
FINAL_PATH="$DEST_DIR/${VM_NAME}-${STAMP}.qcow2"
PART_PATH="${FINAL_PATH}.part"

[ -e "$FINAL_PATH" ] && fail "destination already exists: $FINAL_PATH (remove it first or pick another directory)"
[ -e "$PART_PATH" ] && fail "incomplete backup left over from a previous run: $PART_PATH (remove it first)"

# -c compresses; convert also drops zeroed/leaked clusters while copying.
qemu-img convert -c -O qcow2 "$SOURCE_DISK" "$PART_PATH"
mv -- "$PART_PATH" "$FINAL_PATH"

DIGEST="$(sha256sum "$FINAL_PATH" | awk '{print $1}')"
printf 'backup OK: %s\nSHA-256: %s\n' "$FINAL_PATH" "$DIGEST"

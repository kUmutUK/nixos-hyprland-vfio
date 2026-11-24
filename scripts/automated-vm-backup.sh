#!/usr/bin/env bash
# systemd timer wrapper: fail closed unless the expected external filesystem is mounted.
set -Eeuo pipefail

log() {
  if command -v logger >/dev/null 2>&1; then
    logger --tag vm-backup -- "$*"
  fi
  printf '%s\n' "$*"
}

notify() {
  local urgency="$1" title="$2" message="$3"
  log "$title: $message"
  local user="${BACKUP_NOTIFICATION_USER:-localhost}"
  if ! id "$user" >/dev/null 2>&1 || ! command -v runuser >/dev/null 2>&1 || ! command -v notify-send >/dev/null 2>&1; then
    return 0
  fi
  local uid runtime
  uid="$(id -u "$user")"
  runtime="/run/user/$uid"
  [[ -S "$runtime/bus" ]] || return 0
  runuser -u "$user" -- env \
    XDG_RUNTIME_DIR="$runtime" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
    notify-send --app-name="VM Backup" --urgency="$urgency" "$title" "$message" >/dev/null 2>&1 || true
}

on_exit() {
  local status=$?
  if (( status != 0 )); then
    notify critical "VM backup failed" "Check journal: journalctl -u vm-backup.service"
  fi
}
trap on_exit EXIT

TARGET="${BACKUP_TARGET:-}"
EXPECTED_UUID="${BACKUP_TARGET_UUID:-}"
SOURCE="${BACKUP_SOURCE_DISK:-/mnt/media/win10new.qcow2}"
VM_NAME="${BACKUP_VM_NAME:-win10}"
RETENTION="${BACKUP_RETENTION_COUNT:-4}"
SCRIPT="${BACKUP_VM_SCRIPT_PATH:-$(cd "$(dirname "$0")" && pwd)/backup-vm.sh}"

[[ -n "$TARGET" && -n "$EXPECTED_UUID" ]] || {
  echo "ERROR: configure both BACKUP_TARGET and BACKUP_TARGET_UUID" >&2
  exit 1
}
[[ "$TARGET" = /* ]] || {
  echo "ERROR: BACKUP_TARGET must be an absolute mountpoint" >&2
  exit 1
}

if ! mountpoint -q -- "$TARGET"; then
  log "SKIP: external backup filesystem is not mounted at $TARGET"
  trap - EXIT
  exit 0
fi

MOUNTED_UUID="$(findmnt --noheadings --output UUID --target "$TARGET" 2>/dev/null | tr -d '[:space:]' || true)"
[[ -n "$MOUNTED_UUID" ]] || {
  echo "ERROR: could not determine the mounted filesystem UUID for $TARGET" >&2
  exit 1
}
[[ "$MOUNTED_UUID" == "$EXPECTED_UUID" ]] || {
  echo "ERROR: mounted UUID '$MOUNTED_UUID' differs from expected '$EXPECTED_UUID'" >&2
  exit 1
}
[[ -d "$TARGET" && -w "$TARGET" ]] || {
  echo "ERROR: external backup mountpoint is not writable: $TARGET" >&2
  exit 1
}
[[ -f "$SCRIPT" ]] || {
  echo "ERROR: backup helper not found: $SCRIPT" >&2
  exit 1
}

export BACKUP_VM_NAME="$VM_NAME"
export BACKUP_RETENTION_COUNT="$RETENTION"
export LIBVIRT_DEFAULT_URI="${LIBVIRT_DEFAULT_URI:-qemu:///system}"
bash "$SCRIPT" "$TARGET" "$SOURCE"
notify normal "VM backup completed" "Verified $VM_NAME backup stored on $TARGET"
trap - EXIT

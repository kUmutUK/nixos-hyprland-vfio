#!/usr/bin/env bash
# Mock-backed tests for external mountpoint/UUID checks and safe skip behavior.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
BIN="$TMP/bin"
mkdir -p "$BIN" "$TMP/backup"
export AUTO_BACKUP_LOG="$TMP/log"
export BACKUP_TEST_ARGS_FILE="$TMP/args"

cat > "$BIN/mountpoint" <<'STUB'
#!/usr/bin/env bash
[[ "${MOUNTPOINT_STATE:-mounted}" == "mounted" ]]
STUB
cat > "$BIN/findmnt" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${MOUNT_UUID:-uuid-good}"
STUB
cat > "$BIN/logger" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$AUTO_BACKUP_LOG"
STUB
cat > "$BIN/runuser" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat > "$BIN/notify-send" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$BIN/"*

FAKE_BACKUP="$TMP/fake-backup.sh"
cat > "$FAKE_BACKUP" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$BACKUP_TEST_ARGS_FILE"
STUB
chmod +x "$FAKE_BACKUP"

BASE_ENV=(
  "PATH=$BIN:$PATH"
  "BACKUP_TARGET=$TMP/backup"
  "BACKUP_TARGET_UUID=uuid-good"
  "BACKUP_SOURCE_DISK=$TMP/win10.qcow2"
  "BACKUP_VM_NAME=win10"
  "BACKUP_VM_SCRIPT_PATH=$FAKE_BACKUP"
  "BACKUP_TEST_ARGS_FILE=$BACKUP_TEST_ARGS_FILE"
  "AUTO_BACKUP_LOG=$AUTO_BACKUP_LOG"
)

env "${BASE_ENV[@]}" MOUNTPOINT_STATE=absent bash "$ROOT/scripts/automated-vm-backup.sh" > "$TMP/skip.log"
grep -q '^SKIP:' "$TMP/skip.log" || { echo "missing mount must be an explicit safe skip" >&2; exit 1; }
[ ! -e "$BACKUP_TEST_ARGS_FILE" ] || { echo "backup helper must not run without a mount" >&2; exit 1; }

if env "${BASE_ENV[@]}" MOUNT_UUID=wrong bash "$ROOT/scripts/automated-vm-backup.sh" >/dev/null 2>&1; then
  echo "wrong external filesystem UUID must be rejected" >&2
  exit 1
fi
[ ! -e "$BACKUP_TEST_ARGS_FILE" ] || { echo "backup helper must not run for a wrong UUID" >&2; exit 1; }

env "${BASE_ENV[@]}" MOUNT_UUID=uuid-good bash "$ROOT/scripts/automated-vm-backup.sh" >/dev/null
grep -qx "$TMP/backup" "$BACKUP_TEST_ARGS_FILE" || { echo "verified mountpoint must be passed to backup helper" >&2; exit 1; }
grep -qx "$TMP/win10.qcow2" "$BACKUP_TEST_ARGS_FILE" || { echo "configured source disk must be passed through" >&2; exit 1; }

echo "OK: VM backup wrapper skips absent mounts and rejects incorrect filesystem UUIDs."

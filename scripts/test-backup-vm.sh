#!/usr/bin/env bash
# Regression tests for scripts/backup-vm.sh: fail-closed guards and the
# atomic publish path, using stub virsh/qemu-img binaries on a temp tree.
# The real sha256sum/mv/date utilities are used so the digest and rename
# semantics are exercised exactly as on the host.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/backup-vm.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
VIRSH_LOG="$TMP_DIR/virsh.log"
export VIRSH_LOG
: > "$VIRSH_LOG"
mkdir -m 700 -- "$BIN_DIR"

# virsh stub: only `domstate <name>` is supported; the state is injected via
# VIRSH_STATE and every invocation is recorded for call-order assertions.
cat > "$BIN_DIR/virsh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$VIRSH_LOG"
if [ "${1-}" = "domstate" ] && [ $# -eq 2 ]; then
  printf '%s\n' "${VIRSH_STATE:-shut off}"
  exit 0
fi
echo "virsh-stub: unsupported invocation: $*" >&2
exit 1
STUB

# qemu-img stub: convert writes marker data; check validates that a file exists.
cat > "$BIN_DIR/qemu-img" <<'STUB'
#!/usr/bin/env bash
if [ "${1-}" = "convert" ]; then
  while [ $# -gt 1 ]; do
    shift
  done
  printf 'stub-qcow2-image\n' > "$1"
  exit 0
fi
if [ "${1-}" = "check" ] && [ $# -eq 2 ]; then
  [ -f "$2" ] || exit 1
  exit 0
fi
echo "qemu-img-stub: unsupported invocation: $*" >&2
exit 1
STUB

chmod 700 -- "$BIN_DIR/virsh" "$BIN_DIR/qemu-img"

SOURCE_DISK="$TMP_DIR/win10new.qcow2"
printf 'fake-live-disk\n' > "$SOURCE_DISK"
DEST_DIR="$TMP_DIR/backups"
mkdir -m 700 -- "$DEST_DIR"
export BACKUP_VM_NAME="win10"

run_script() {
  PATH="$BIN_DIR:$PATH" bash "$SCRIPT" "$@"
}

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

# 1. Happy path: shut-off VM publishes an atomic backup with a digest.
unset VIRSH_STATE
OUTPUT="$(run_script "$DEST_DIR" "$SOURCE_DISK")" || fail_test "shut-off backup must succeed"
FINAL_PATH="$DEST_DIR/win10-$(date +%F).qcow2"
[ -f "$FINAL_PATH" ] || fail_test "published backup file missing: $FINAL_PATH"
[ -e "$FINAL_PATH.part" ] && fail_test "temporary .part file left behind after success"
[ -f "$FINAL_PATH.sha256" ] || fail_test "SHA-256 sidecar missing"
(cd "$DEST_DIR" && sha256sum -c "$(basename "$FINAL_PATH").sha256" >/dev/null) || fail_test "published backup checksum must verify"
EXPECTED_DIGEST="$(sha256sum "$FINAL_PATH" | awk '{print $1}')"
case "$OUTPUT" in
  *"backup OK: $FINAL_PATH"*) ;;
  *) fail_test "success output must name the published file" ;;
esac
case "$OUTPUT" in
  *"SHA-256: $EXPECTED_DIGEST"*) ;;
  *) fail_test "success output must report the real SHA-256 digest" ;;
esac
grep -qxF "domstate win10" "$VIRSH_LOG" || fail_test "script must query domstate for the configured VM name"

# 2. Refuse to overwrite an existing backup of the same day.
if OUTPUT="$(run_script "$DEST_DIR" "$SOURCE_DISK" 2>/dev/null)"; then
  fail_test "an existing destination file must make the script fail"
fi
[ "$(grep -c '^domstate win10$' "$VIRSH_LOG")" -eq 2 ] \
  || fail_test "overwrite refusal must reuse exactly the domstate check, nothing more"

# 3. Refuse when the VM is running; no destination files may appear.
RUNNING_DEST="$TMP_DIR/running-backups"
mkdir -m 700 -- "$RUNNING_DEST"
export VIRSH_STATE="running"
if OUTPUT="$(run_script "$RUNNING_DEST" "$SOURCE_DISK" 2>/dev/null)"; then
  fail_test "a running VM must make the script fail"
fi
[ -z "$(ls -A "$RUNNING_DEST")" ] || fail_test "a running VM must not produce any destination files"
unset VIRSH_STATE

# 4. Refuse when a leftover .part blocks the destination.
PART_DEST="$TMP_DIR/part-backups"
mkdir -m 700 -- "$PART_DEST"
printf 'interrupted\n' > "$PART_DEST/win10-$(date +%F).qcow2.part"
if OUTPUT="$(run_script "$PART_DEST" "$SOURCE_DISK" 2>/dev/null)"; then
  fail_test "a leftover .part file must make the script fail"
fi
[ "$(cat "$PART_DEST/win10-$(date +%F).qcow2.part")" = "interrupted" ] \
  || fail_test "the leftover .part file must be left untouched"

# 5. Refuse a missing source disk image.
if OUTPUT="$(run_script "$DEST_DIR" "$TMP_DIR/does-not-exist.qcow2" 2>/dev/null)"; then
  fail_test "a missing source disk must make the script fail"
fi

# 6. Refuse a destination that is not a directory.
if OUTPUT="$(run_script "$SOURCE_DISK" "$SOURCE_DISK" 2>/dev/null)"; then
  fail_test "a non-directory destination must make the script fail"
fi

# 7. Missing destination argument prints usage instead of touching anything.
if OUTPUT="$(run_script 2>/dev/null)"; then
  fail_test "a missing destination argument must make the script fail"
fi
case "$OUTPUT" in
  *Usage:*) ;;
  *) fail_test "a missing destination argument must print the usage block" ;;
esac

# 8. Keep only the newest configured number of verified backups.
RETENTION_DEST="$TMP_DIR/retention-backups"
mkdir -m 700 -- "$RETENTION_DEST"
for day in 01 02 03; do
  name="win10-2026-10-$day.qcow2"
  printf 'older-backup-%s\n' "$day" > "$RETENTION_DEST/$name"
  (cd "$RETENTION_DEST" && sha256sum "$name" > "$name.sha256")
done
BACKUP_RETENTION_COUNT=2 PATH="$BIN_DIR:$PATH" bash "$SCRIPT" "$RETENTION_DEST" "$SOURCE_DISK" >/dev/null
[ -f "$RETENTION_DEST/win10-$(date +%F).qcow2" ] || fail_test "newest backup must remain"
[ -f "$RETENTION_DEST/win10-2026-10-03.qcow2" ] || fail_test "second-newest verified backup must remain"
[ ! -e "$RETENTION_DEST/win10-2026-10-01.qcow2" ] || fail_test "oldest verified backup must be pruned"
[ ! -e "$RETENTION_DEST/win10-2026-10-02.qcow2" ] || fail_test "second-oldest verified backup must be pruned"

echo "OK: VM disk backup guards, qcow2 validation, SHA-256 sidecar, atomic publish, and retention passed."

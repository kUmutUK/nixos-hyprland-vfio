#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vm-bootstrap-regression.XXXXXX")"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

LIBVIRT_ROOT="$TMP_ROOT/libvirt"
HOME_DIR="$TMP_ROOT/home"
REPO="$HOME_DIR/nixos-hyprland-vfio"
MOCK_BIN="$TMP_ROOT/mock-bin"
REAL_MV="$(command -v mv)"
PREPARE_SCRIPT="$TMP_ROOT/prepare-vm.sh"
VIRSH_LOG="$TMP_ROOT/virsh.log"
mkdir -p "$REPO/.git" "$REPO/scripts" "$REPO/vm-xml" "$MOCK_BIN" \
  "$LIBVIRT_ROOT/images" "$LIBVIRT_ROOT/qemu" "$HOME_DIR"
cp "$ROOT/scripts/sync-vm-xml.py" "$REPO/scripts/"
cp "$ROOT/scripts/check-vm-iso-paths.py" "$REPO/scripts/"
sed "s|/var/lib/libvirt|$LIBVIRT_ROOT|g" "$ROOT/vm-xml/win10.xml" > "$REPO/vm-xml/win10.xml"

cat > "$MOCK_BIN/sudo" <<'SH'
#!/usr/bin/env bash
set -e
exec "$@"
SH
cat > "$MOCK_BIN/virsh" <<'SH'
#!/usr/bin/env bash
set -e
case "${1:-}" in
  list) exit 0 ;;
  define) printf '%s\n' "$*" >> "$VIRSH_LOG"; exit 0 ;;
  *) printf 'unexpected virsh command: %s\n' "$*" >&2; exit 2 ;;
esac
SH
cat > "$MOCK_BIN/qemu-img" <<'SH'
#!/usr/bin/env bash
set -e
if [ "$#" -ne 5 ] || [ "$1" != create ] || [ "$2" != -f ] || [ "$3" != qcow2 ]; then
  printf 'unexpected qemu-img arguments: %s\n' "$*" >&2
  exit 2
fi
target="$4"
if [ "${FAIL_QEMU_IMG:-0}" = 1 ]; then
  printf 'partial-qcow2' > "$target"
  exit 42
fi
printf 'fake-qcow2' > "$target"
SH
cat > "$MOCK_BIN/chown" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$MOCK_BIN/mv" <<'SH'
#!/usr/bin/env bash
set -e
if [ "${RACE_XML_ON_PUBLISH:-0}" = 1 ]; then
  source_path="${4:-}"
  destination="${5:-}"
  case "$source_path" in
    */.win10-bootstrap.*/win10.xml)
      if [ "$destination" = "${VM_XML_PATH:-}" ]; then
        printf 'concurrent-writer-xml\n' > "$destination"
      fi
      ;;
  esac
fi
exec "${REAL_MV:?}" "$@"
SH
chmod +x "$MOCK_BIN/"*

python3 - "$ROOT/README.md" "$PREPARE_SCRIPT" "$LIBVIRT_ROOT" "$TMP_ROOT/etc-nixos" <<'PY'
from pathlib import Path
import sys

readme, output, libvirt_root, etc_nixos = sys.argv[1:]
text = Path(readme).read_text(encoding="utf-8")
anchor = "After the first system activation and reboot, prepare the VM disk and define the domain."
section = text.index(anchor)
start = text.index(chr(96) * 3 + "bash\n", section) + len(chr(96) * 3 + "bash\n")
end = text.index("\n" + chr(96) * 3, start)
block = text[start:end]
block = block.replace("/var/lib/libvirt", libvirt_root)
block = block.replace("/etc/nixos", etc_nixos)
Path(output).write_text(block + "\n", encoding="utf-8")
PY

VM_XML="$LIBVIRT_ROOT/win10.xml"
DISK_PATH="$LIBVIRT_ROOT/images/win10new.qcow2"
WIN_ISO="$LIBVIRT_ROOT/images/Win10_22H2_English_x64v1.iso"
VIRTIO_ISO="$LIBVIRT_ROOT/images/virtio-win-0.1.285.iso"

run_prepare() {
  printf '%s\n' '0000:0b:02.0' '0000:0b:02.1' |
    env HOME="$HOME_DIR" PATH="$MOCK_BIN:$PATH" VIRSH_LOG="$VIRSH_LOG" \
      REAL_MV="$REAL_MV" VM_XML_PATH="$VM_XML" "$@" bash "$PREPARE_SCRIPT"
}
assert_no_staging_dirs() {
  if find "$LIBVIRT_ROOT" "$LIBVIRT_ROOT/images" -maxdepth 1 -type d -name '.win10-bootstrap.*' -print -quit | grep -q .; then
    echo "FAIL: temporary VM bootstrap directories were not cleaned up." >&2
    exit 1
  fi
}

# Missing ISO: the first run must fail without leaving a deployed XML or disk.
if run_prepare >/dev/null 2>&1; then
  echo "FAIL: VM setup unexpectedly passed with missing ISO files." >&2
  exit 1
fi
if [ -e "$VM_XML" ] || [ -e "$DISK_PATH" ]; then
  echo "FAIL: missing ISO left a deployed XML or final-path disk." >&2
  exit 1
fi
assert_no_staging_dirs

# A failed qemu-img that leaves a partial staging file must not poison the retry.
touch "$WIN_ISO" "$VIRTIO_ISO"
if run_prepare FAIL_QEMU_IMG=1 >/dev/null 2>&1; then
  echo "FAIL: VM setup unexpectedly passed after qemu-img failure." >&2
  exit 1
fi
if [ -e "$VM_XML" ] || [ -e "$DISK_PATH" ]; then
  echo "FAIL: failed disk creation left a deployed XML or final-path partial disk." >&2
  exit 1
fi
assert_no_staging_dirs

# A pre-existing orphan/partial final disk must be preserved, never adopted or overwritten.
printf 'pre-existing-partial-disk' > "$DISK_PATH"
if run_prepare >/dev/null 2>&1; then
  echo "FAIL: VM setup silently adopted a disk that existed without a deployed XML." >&2
  exit 1
fi
if [ -e "$VM_XML" ] || ! grep -Fxq 'pre-existing-partial-disk' "$DISK_PATH"; then
  echo "FAIL: orphan-disk refusal changed the disk or published a VM XML." >&2
  exit 1
fi
assert_no_staging_dirs
rm -f -- "$DISK_PATH"

# If another process claims the final XML path after disk publication, preserve its XML
# and roll back only the disk inode created by this run.
if run_prepare RACE_XML_ON_PUBLISH=1 >/dev/null 2>&1; then
  echo "FAIL: VM setup unexpectedly passed after a concurrent XML destination was created." >&2
  exit 1
fi
if [ -e "$DISK_PATH" ]; then
  echo "FAIL: concurrent XML publication failure left this run's disk orphaned." >&2
  exit 1
fi
if [ ! -f "$VM_XML" ] || ! grep -Fxq 'concurrent-writer-xml' "$VM_XML"; then
  echo "FAIL: rollback removed or overwrote the concurrent writer's XML." >&2
  exit 1
fi
assert_no_staging_dirs
rm -f -- "$VM_XML"

# With all prerequisites present, the second attempt publishes both assets and defines the VM.
if ! run_prepare >/dev/null 2>&1; then
  echo "FAIL: VM setup did not recover after ISO/disk prerequisites were corrected." >&2
  exit 1
fi
if [ ! -s "$VM_XML" ] || [ ! -s "$DISK_PATH" ] || ! grep -Fq "define $VM_XML" "$VIRSH_LOG"; then
  echo "FAIL: successful VM bootstrap did not publish the XML/disk and define the domain." >&2
  exit 1
fi
assert_no_staging_dirs

echo "OK: missing-ISO retry, staged disk failure cleanup, orphan-disk refusal, and successful VM bootstrap passed."

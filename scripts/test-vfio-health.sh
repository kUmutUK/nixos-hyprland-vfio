#!/usr/bin/env bash
# Regression tests for scripts/vfio-health.sh using a fake /sys tree, a fake
# hook log, and a stub qemu-img. All paths are injected through the
# VFIO_HEALTH_* environment overrides; no real /sys or VM state is read.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/vfio-health.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TMP_DIR"' EXIT

BIN_DIR="$TMP_DIR/bin"
mkdir -m 700 -- "$BIN_DIR"

# qemu-img stub: `check` fails on images whose content marks them corrupt.
cat > "$BIN_DIR/qemu-img" <<'STUB'
#!/usr/bin/env bash
if [ "${1-}" = "check" ] && [ $# -eq 2 ]; then
  if grep -q "CORRUPT" "$2"; then
    echo "stub: image corruption detected" >&2
    exit 1
  fi
  echo "stub: No errors were found on the image."
  exit 0
fi
echo "qemu-img-stub: unsupported invocation: $*" >&2
exit 1
STUB
chmod 700 -- "$BIN_DIR/qemu-img"

fail_test() {
  echo "FAIL: $*" >&2
  exit 1
}

run_health() {
  PATH="$BIN_DIR:$PATH" \
    VFIO_HEALTH_SYS_ROOT="$CASE_SYS" \
    VFIO_HEALTH_LOG="$CASE_LOG" \
    VFIO_HEALTH_DISK="$CASE_DISK" \
    bash "$SCRIPT"
}

new_case() {
  CASE_NAME="$1"
  CASE_SYS="$TMP_DIR/$2-sys"
  CASE_LOG="$TMP_DIR/$2.log"
  CASE_DISK="$TMP_DIR/$2.qcow2"
  mkdir -m 700 -p -- "$CASE_SYS/kernel/iommu_groups" "$CASE_SYS/bus/pci/devices"
}

# Fake PCI device with an IOMMU group and a driver symlink. The symlinks are
# absolute so they resolve identically regardless of the tree depth.
add_pci_device() {
  device="$1"
  group="$2"
  driver="$3"
  device_dir="$CASE_SYS/bus/pci/devices/$device"
  mkdir -m 700 -p -- "$device_dir" "$CASE_SYS/kernel/iommu_groups/$group"
  ln -s "$CASE_SYS/kernel/iommu_groups/$group" "$device_dir/iommu_group"
  if [ "$driver" != "none" ]; then
    mkdir -m 700 -p -- "$CASE_SYS/bus/pci/drivers/$driver"
    ln -s "$CASE_SYS/bus/pci/drivers/$driver" "$device_dir/driver"
  fi
}

# 1. Healthy host: IOMMU groups, drivers on the host drivers, clean log since
# the last release, healthy disk. Must exit 0 and report no anomalies.
new_case healthy healthy
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 snd_hda_intel
cat > "$CASE_LOG" <<'LOG'
[2026-11-24 09:00:00] VM win10 stopped; restoring the GPU to the host...
[2026-11-24 09:00:05] Started greetd...
LOG
printf 'healthy-image\n' > "$CASE_DISK"
OUTPUT="$(run_health)" || fail_test "healthy host must exit 0 (got: $OUTPUT)"
case "$OUTPUT" in
  *"health: no anomalies found"*) ;;
  *) fail_test "healthy host must report no anomalies" ;;
esac
case "$OUTPUT" in
  *"IOMMU: 1 groups resolved"* | *"IOMMU: 1 group"*) ;;
  *) fail_test "healthy host must report the resolved IOMMU group count" ;;
esac
case "$OUTPUT" in
  *"driver: 0000:0b:00.0 -> amdgpu"*) ;;
  *) fail_test "healthy host must report the GPU host driver" ;;
esac
case "$OUTPUT" in
  *"disk: qemu-img check OK"*) ;;
  *) fail_test "healthy host must pass the disk check" ;;
esac

# 2. VM running: functions on vfio-pci is NOT an anomaly; still exit 0.
new_case running running
add_pci_device "0000:0b:00.0" 12 vfio-pci
add_pci_device "0000:0b:00.1" 12 vfio-pci
printf 'healthy-image\n' > "$CASE_DISK"
OUTPUT="$(run_health)" || fail_test "a running VM (vfio-pci drivers) must not be flagged"
case "$OUTPUT" in
  *"driver: 0000:0b:00.1 -> vfio-pci"*) ;;
  *) fail_test "the audio function driver must still be reported while the VM runs" ;;
esac

# 3. IOMMU missing entirely: anomaly, exit 1.
new_case noiommu noiommu
printf 'healthy-image\n' > "$CASE_DISK"
if OUTPUT="$(run_health 2>/dev/null)"; then
  fail_test "a missing IOMMU group tree must fail the health check"
fi

# 4. A device with no IOMMU group: anomaly, exit 1.
new_case nogroup nogroup
add_pci_device "0000:0b:00.0" 12 amdgpu
device_dir="$CASE_SYS/bus/pci/devices/0000:0b:00.1"
mkdir -m 700 -p -- "$device_dir" "$CASE_SYS/bus/pci/drivers/snd_hda_intel"
ln -s "$CASE_SYS/bus/pci/drivers/snd_hda_intel" "$device_dir/driver"
if OUTPUT="$(run_health 2>/dev/null)"; then
  fail_test "an ungrouped PCI function must fail the health check"
fi

# 5. A device with no driver bound: anomaly, exit 1.
new_case nodriver nodriver
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 none
if OUTPUT="$(run_health 2>/dev/null)"; then
  fail_test "an unbound PCI function must fail the health check"
fi

# 6. ERROR in the hook log AFTER the last release: anomaly, exit 1.
new_case logerror logerror
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 snd_hda_intel
cat > "$CASE_LOG" <<'LOG'
[2026-11-24 09:00:00] ERROR: something went wrong before this release
[2026-11-24 10:00:00] VM win10 stopped; restoring the GPU to the host...
[2026-11-24 10:00:07] Started greetd...
[2026-11-24 11:00:00] CRITICAL: the display may stay black
LOG
printf 'healthy-image\n' > "$CASE_DISK"
if OUTPUT="$(run_health 2>&1)"; then
  fail_test "a CRITICAL line after the last release must fail the health check"
fi
case "$OUTPUT" in
  *"CRITICAL: the display may stay black"*) ;;
  *) fail_test "the reported anomaly must quote the offending log line" ;;
esac

# 7. ERROR in the hook log BEFORE the last release: historical, exit 0.
new_case olderror olderror
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 snd_hda_intel
cat > "$CASE_LOG" <<'LOG'
[2026-11-24 09:00:00] ERROR: something went wrong before this release
[2026-11-24 10:00:00] VM win10 stopped; restoring the GPU to the host...
[2026-11-24 10:00:07] Started greetd...
LOG
printf 'healthy-image\n' > "$CASE_DISK"
OUTPUT="$(run_health)" || fail_test "a pre-release historical ERROR must not fail the health check"

# 8. Corrupt disk: anomaly, exit 1.
new_case corruptdisk corruptdisk
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 snd_hda_intel
printf 'CORRUPT-image\n' > "$CASE_DISK"
if OUTPUT="$(run_health 2>/dev/null)"; then
  fail_test "a failing qemu-img check must fail the health check"
fi

# 9. Missing log and missing disk: informational skips, exit 0.
new_case sparse sparse
add_pci_device "0000:0b:00.0" 12 amdgpu
add_pci_device "0000:0b:00.1" 12 snd_hda_intel
OUTPUT="$(run_health)" || fail_test "missing log/disk must stay informational"
case "$OUTPUT" in
  *"not readable yet; skipped"* | *"missing or qemu-img unavailable; skipped"*) ;;
  *) fail_test "missing log/disk must be reported as skipped" ;;
esac

echo "OK: VFIO health-check IOMMU, log, driver, and disk regression tests passed."

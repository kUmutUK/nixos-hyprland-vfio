#!/usr/bin/env bash
# VFIO/VM health report: read-only checks over the IOMMU topology, the vfio
# hook log since the last VM release, the two passed-through PCI functions,
# and the Windows guest disk. Run it any time; it never writes anywhere
# except stdout/stderr and never touches the VM, its disk, or hook state.
#
# Exit status: 0 when no anomaly is found, 1 when at least one check flags an
# anomaly. Informational lines (skips, current driver state) never fail the
# run: the GPU functions legitimately sit on vfio-pci while the VM runs and
# on amdgpu/snd_hda_intel while the host owns them.
#
# Usage: scripts/vfio-health.sh
# Environment overrides (used by the regression test to fake a /sys tree):
#   VFIO_HEALTH_SYS_ROOT (default /sys)
#   VFIO_HEALTH_LOG      (default /var/log/libvirt/vfio.log)
#   VFIO_HEALTH_DISK     (default /mnt/media/win10new.qcow2)
#   VFIO_HEALTH_GPU_PCI  (default 0000:0b:00.0, hook GPU_PCI)
#   VFIO_HEALTH_GPU_AUDIO (default 0000:0b:00.1, hook GPU_AUDIO)
set -euo pipefail

SYS_ROOT="${VFIO_HEALTH_SYS_ROOT:-/sys}"
VFIO_LOG="${VFIO_HEALTH_LOG:-/var/log/libvirt/vfio.log}"
VM_DISK="${VFIO_HEALTH_DISK:-/mnt/media/win10new.qcow2}"
GPU_PCI="${VFIO_HEALTH_GPU_PCI:-0000:0b:00.0}"
GPU_AUDIO="${VFIO_HEALTH_GPU_AUDIO:-0000:0b:00.1}"

anomaly_count=0
report() {
  printf '%s\n' "$*"
}
warn() {
  printf 'ANOMALY: %s\n' "$*" >&2
  anomaly_count=$((anomaly_count + 1))
}

# 1. IOMMU groups are resolved and both GPU functions belong to a group.
iommu_root="$SYS_ROOT/kernel/iommu_groups"
if [ -d "$iommu_root" ] && [ -n "$(ls -A "$iommu_root" 2>/dev/null)" ]; then
  group_total="$(find "$iommu_root" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  report "IOMMU: $group_total groups resolved under $iommu_root"
  for device in "$GPU_PCI" "$GPU_AUDIO"; do
    group_link="$SYS_ROOT/bus/pci/devices/$device/iommu_group"
    if [ -e "$group_link" ]; then
      report "IOMMU: $device in group $(basename "$(readlink "$group_link")")"
    else
      warn "no IOMMU group resolved for $device"
    fi
  done
else
  warn "no IOMMU groups under $iommu_root (IOMMU disabled or not initialized)"
fi

# 2. The hook log records no ERROR/CRITICAL line after the last VM release.
if [ -r "$VFIO_LOG" ]; then
  release_mark="restoring the GPU to the host"
  last_release_line="$(grep -n -F "$release_mark" "$VFIO_LOG" | tail -1 | cut -d: -f1 || true)"
  if [ -n "$last_release_line" ]; then
    report "hook log: last VM release record at line $last_release_line of $VFIO_LOG"
    problems="$(tail -n +"$((last_release_line + 1))" "$VFIO_LOG" | grep -E 'ERROR:|CRITICAL:' || true)"
    if [ -n "$problems" ]; then
      while IFS= read -r line; do
        warn "hook log since last release: $line"
      done <<< "$problems"
    else
      report "hook log: no ERROR/CRITICAL lines since the last release"
    fi
  else
    report "hook log: no VM release record yet in $VFIO_LOG (the VM has not run)"
  fi
else
  report "hook log: $VFIO_LOG not readable yet; skipped"
fi

# 3. Report the current driver of both functions; only an unbound function is
# an anomaly — vfio-pci (VM running) and the host drivers are both healthy.
for device in "$GPU_PCI" "$GPU_AUDIO"; do
  driver_link="$SYS_ROOT/bus/pci/devices/$device/driver"
  if [ -e "$driver_link" ]; then
    report "driver: $device -> $(basename "$(readlink "$driver_link")")"
  else
    warn "no driver bound to $device"
  fi
done

# 4. Read-only qcow2 structural check of the Windows disk.
if command -v qemu-img >/dev/null 2>&1 && [ -f "$VM_DISK" ]; then
  check_output="$(qemu-img check "$VM_DISK" 2>&1)" \
    && report "disk: qemu-img check OK for $VM_DISK" \
    || warn "qemu-img check failed for $VM_DISK: $(printf '%s\n' "$check_output" | tail -1)"
else
  report "disk: $VM_DISK missing or qemu-img unavailable; skipped"
fi

if [ "$anomaly_count" -gt 0 ]; then
  report "health: $anomaly_count anomaly(ies) found"
  exit 1
fi
report "health: no anomalies found"

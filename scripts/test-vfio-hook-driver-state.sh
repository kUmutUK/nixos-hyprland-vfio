#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_DIR/nixos/hooks/qemu"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

extract_function() {
  local function_name="$1"
  awk -v wanted="${function_name}() {" '
    $0 == wanted { inside = 1 }
    inside { print }
    inside && $0 == "}" { exit }
  ' "$HOOK"
}

FUNCTIONS_FILE="$TMP_DIR/functions.sh"
: > "$FUNCTIONS_FILE"
for function_name in device_driver_name device_has_real_driver device_bound_to_vfio restore_prepare_device; do
  function_text="$(extract_function "$function_name")"
  [[ "$function_text" == *"${function_name}()"* ]] || fail "could not extract $function_name from hook"
  printf '%s\n\n' "$function_text" >> "$FUNCTIONS_FILE"
done

# shellcheck disable=SC1090
source "$FUNCTIONS_FILE"

# Mock side effects from rollback; no real /sys files are touched.
released_devices=()
log() { :; }
release_host_driver() { released_devices+=("$1"); }

DEVICES_ROOT="$TMP_DIR/sys/bus/pci/devices"
DRIVERS_ROOT="$TMP_DIR/sys/bus/pci/drivers"
DEVICE="0000:0b:00.0"
mkdir -p "$DEVICES_ROOT/$DEVICE" "$DRIVERS_ROOT/amdgpu" "$DRIVERS_ROOT/vfio-pci"

# No driver symlink: readlink -f would still return a path ending in /driver.
# The fixed helper must instead treat this device as unbound.
if device_driver_name "$DEVICE" "$DEVICES_ROOT" >/dev/null 2>&1; then
  fail 'unbound device was reported as having a driver'
fi
if device_has_real_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'unbound device was reported as having a real host driver'
fi
if device_bound_to_vfio "$DEVICE" "$DEVICES_ROOT"; then
  fail 'unbound device was reported as bound to vfio-pci'
fi
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 1 && "${released_devices[0]}" == "$DEVICE" ]] \
  || fail 'rollback did not try to restore the host driver for an unbound device'

# A normal host driver must be detected, and rollback must not unbind it.
: > "$DEVICES_ROOT/$DEVICE/driver_override"
ln -s "$DRIVERS_ROOT/amdgpu" "$DEVICES_ROOT/$DEVICE/driver"
[[ "$(device_driver_name "$DEVICE" "$DEVICES_ROOT")" == 'amdgpu' ]] \
  || fail 'amdgpu driver name was not detected'
device_has_real_driver "$DEVICE" "$DEVICES_ROOT" \
  || fail 'amdgpu was not recognized as a real driver'
if device_bound_to_vfio "$DEVICE" "$DEVICES_ROOT"; then
  fail 'amdgpu was reported as vfio-pci'
fi
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 1 ]] \
  || fail 'rollback attempted to replace a still-bound host driver'
[[ -z "$(cat "$DEVICES_ROOT/$DEVICE/driver_override")" ]] \
  || fail 'rollback did not clear driver_override for a host-bound device'

# vfio-pci is bound, but is not a real host driver; rollback must reprobe it.
rm "$DEVICES_ROOT/$DEVICE/driver"
ln -s "$DRIVERS_ROOT/vfio-pci" "$DEVICES_ROOT/$DEVICE/driver"
[[ "$(device_driver_name "$DEVICE" "$DEVICES_ROOT")" == 'vfio-pci' ]] \
  || fail 'vfio-pci driver name was not detected'
if device_has_real_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'vfio-pci was incorrectly reported as a real host driver'
fi
device_bound_to_vfio "$DEVICE" "$DEVICES_ROOT" \
  || fail 'vfio-pci was not detected'
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 2 ]] \
  || fail 'rollback did not try to restore the host driver from vfio-pci'

# A broken symlink must be treated as unresolved, not as a driver name.
rm "$DEVICES_ROOT/$DEVICE/driver"
ln -s "$DRIVERS_ROOT/missing-driver" "$DEVICES_ROOT/$DEVICE/driver"
if device_driver_name "$DEVICE" "$DEVICES_ROOT" >/dev/null 2>&1; then
  fail 'broken driver symlink was treated as a valid driver'
fi

printf 'OK: VFIO driver-state detection and rollback regression tests passed.\n'

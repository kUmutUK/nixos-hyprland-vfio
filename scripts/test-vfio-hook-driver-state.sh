#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_DIR/nixos/hooks/qemu"
CONFIG="$REPO_DIR/nixos/configuration.nix"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# The hook runs with libvirtd's controlled PATH, not the interactive user's PATH.
# nixfmt may format the Nix interpolation across several lines; validate the block semantically.
python3 - "$CONFIG" <<'PY'
import re
import sys
from pathlib import Path

configuration = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(
    r'export PATH="\\$\\{\\s*lib\\.makeBinPath\\s*\\[(.*?)\\]\\s*\\}?:?\\$PATH"',
    configuration,
    re.DOTALL,
)
if match is None or "pkgs.gawk" not in match.group(1):
    raise SystemExit(
        "FAIL: libvirt hook PATH must explicitly include pkgs.gawk for service-state restoration"
    )
PY

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
for function_name in device_driver_name device_has_real_driver device_bound_to_vfio restore_prepare_device save_service_state restore_saved_services; do
  function_text="$(extract_function "$function_name")"
  [[ "$function_text" == *"${function_name}()"* ]] || fail "could not extract $function_name from hook"
  printf '%s\n\n' "$function_text" >> "$FUNCTIONS_FILE"
done

# shellcheck disable=SC1090
source "$FUNCTIONS_FILE"

# All service-state files are redirected into a temporary directory; no real systemd
# services or /run/libvirt state are touched by this regression test.
VFIO_STATE_DIR="$TMP_DIR/vfio-state"
SERVICE_STATE_FILE="$VFIO_STATE_DIR/win10-services.state"
declare -A MOCK_ACTIVE=([greetd]=1 [ollama]=0 [polkit.service]=1 [waydroid-container.service]=1)
declare -a MOCK_STARTED=()
systemctl() {
  local action="$1" service
  case "$action" in
    show)
      service="$4"
      if [[ "${MOCK_ACTIVE[$service]:-0}" == "1" ]]; then
        printf 'active\n'
      else
        printf 'inactive\n'
      fi
      ;;
    start)
      service="$2"
      MOCK_ACTIVE["$service"]=1
      MOCK_STARTED+=("$service")
      ;;
    stop)
      service="$2"
      MOCK_ACTIVE["$service"]=0
      ;;
    *) fail "unexpected mocked systemctl action: $*" ;;
  esac
}

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

# Previously inactive Ollama must remain stopped after the VM closes. Active greetd
# and polkit must return to active state. This models the prepare/release process split.
save_service_state || fail 'could not capture original mocked service activity'
[[ "$(cat "$SERVICE_STATE_FILE")" == $'greetd=1\nollama=0\npolkit.service=1\nwaydroid-container.service=1' ]] \
  || fail 'saved service-state file does not preserve prior active/inactive state'
MOCK_ACTIVE[greetd]=0
MOCK_ACTIVE[ollama]=0
MOCK_ACTIVE[polkit.service]=0
MOCK_ACTIVE[waydroid-container.service]=0
restore_saved_services || fail 'service-state restoration reported failure'
[[ "${MOCK_ACTIVE[greetd]}" == "1" ]] || fail 'greetd was not restored to active state'
[[ "${MOCK_ACTIVE[polkit.service]}" == "1" ]]
[[ "${MOCK_ACTIVE[polkit.service]}" == "1" ]] || fail 'polkit was not restored to active state'
[[ "${MOCK_ACTIVE[waydroid-container.service]}" == "1" ]] || fail 'Waydroid was not restored to active state'
[[ "${MOCK_ACTIVE[ollama]}" == "0" ]] || fail 'Ollama was started despite being inactive before VM start'
[[ ! -e "$SERVICE_STATE_FILE" ]] || fail 'service-state file was not removed after successful restoration'

# If every service was initially inactive, release must not start any of them.
if ! grep -Fq 'for svc in ollama polkit.service waydroid-container.service; do' "$HOOK"; then
  fail 'the VFIO hook must stop Waydroid before handing its single GPU to the VM'
fi
MOCK_ACTIVE[greetd]=0
MOCK_ACTIVE[ollama]=0
MOCK_ACTIVE[polkit.service]=0
MOCK_ACTIVE[waydroid-container.service]=0
started_count="${#MOCK_STARTED[@]}"
save_service_state || fail 'could not capture all-inactive service state'
restore_saved_services || fail 'all-inactive restoration reported failure'
[[ "${#MOCK_STARTED[@]}" -eq "$started_count" ]] || fail 'a service was started despite all services being initially inactive'

printf 'OK: VFIO driver-state and pre-VM service-state regression tests passed.\n'

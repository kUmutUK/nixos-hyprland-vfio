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
    r'export PATH="\$\{\s*lib\.makeBinPath\s*\[(.*?)\]\s*\}:\$PATH"',
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
for function_name in device_driver_name device_has_expected_host_driver device_bound_to_vfio restore_prepare_device rollback_prepare save_service_state stop_saved_service restore_saved_services restore_vfio_state; do
  function_text="$(extract_function "$function_name")"
  [[ "$function_text" == *"${function_name}()"* ]] || fail "could not extract $function_name from hook"
  printf '%s\n\n' "$function_text" >> "$FUNCTIONS_FILE"
done

# shellcheck disable=SC1090
source "$FUNCTIONS_FILE"

# Use the hook's configured BDFs so a deliberate address change does not make
# this test silently exercise a different function.
GPU_PCI="$(sed -n 's/^GPU_PCI="\([^"]*\)"$/\1/p' "$HOOK")"
GPU_AUDIO="$(sed -n 's/^GPU_AUDIO="\([^"]*\)"$/\1/p' "$HOOK")"
[[ -n "$GPU_PCI" && -n "$GPU_AUDIO" && "$GPU_PCI" != "$GPU_AUDIO" ]] \
  || fail 'could not resolve distinct GPU and audio PCI defaults from the hook'

# All service-state files are redirected into a temporary directory; no real systemd
# services or /run/libvirt state are touched by this regression test.
VFIO_STATE_DIR="$TMP_DIR/vfio-state"
SERVICE_STATE_FILE="$VFIO_STATE_DIR/win10-services.state"
declare -A MOCK_ACTIVE=([greetd]=1 [ollama]=0 [polkit.service]=1 [waydroid-container.service]=1)
declare -a MOCK_STARTED=()
MOCK_STOP_FAIL=""
MOCK_START_FAIL=""
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
      if [[ "$MOCK_START_FAIL" == "$service" ]]; then
        return 1
      fi
      MOCK_ACTIVE["$service"]=1
      MOCK_STARTED+=("$service")
      ;;
    stop)
      service="$2"
      if [[ "$MOCK_STOP_FAIL" == "$service" ]]; then
        return 1
      fi
      MOCK_ACTIVE["$service"]=0
      ;;
    *) fail "unexpected mocked systemctl action: $*" ;;
  esac
}

# Mock side effects from rollback; no real /sys files are touched.
released_devices=()
MOCK_RELEASE_FAIL_FOR=""
MOCK_FALLBACK_RECOVERS=0
MOCK_FALLBACK_CALLS=0
MOCK_FALLBACK_ARGS=()
START_HYPRLAND_CALLS=0
MOCK_LOG=()
log() { MOCK_LOG+=("$*"); }
bind_mock_expected_host_driver() {
  local dev="$1" expected
  case "$dev" in
    "$GPU_PCI") expected="amdgpu" ;;
    "$GPU_AUDIO") expected="snd_hda_intel" ;;
    *) fail "unexpected mock PCI function: $dev" ;;
  esac
  rm -f -- "$DEVICES_ROOT/$dev/driver"
  ln -s "$DRIVERS_ROOT/$expected" "$DEVICES_ROOT/$dev/driver"
}
release_host_driver() {
  local dev="$1"
  released_devices+=("$dev")
  if [[ "$MOCK_RELEASE_FAIL_FOR" != "$dev" ]]; then
    bind_mock_expected_host_driver "$dev"
  else
    rm -f -- "$DEVICES_ROOT/$dev/driver"
  fi
}
suspend_rescan_recovery() {
  MOCK_FALLBACK_CALLS=$((MOCK_FALLBACK_CALLS + 1))
  MOCK_FALLBACK_ARGS=("$@")
  if [[ "$MOCK_FALLBACK_RECOVERS" == "1" ]]; then
    for dev in "$@"; do
      bind_mock_expected_host_driver "$dev"
    done
  fi
}
start_hyprland() {
  START_HYPRLAND_CALLS=$((START_HYPRLAND_CALLS + 1))
}

DEVICES_ROOT="$TMP_DIR/sys/bus/pci/devices"
DRIVERS_ROOT="$TMP_DIR/sys/bus/pci/drivers"
DEVICE="$GPU_PCI"
AUDIO_DEVICE="$GPU_AUDIO"
mkdir -p "$DEVICES_ROOT/$DEVICE" "$DEVICES_ROOT/$AUDIO_DEVICE" \
  "$DRIVERS_ROOT/amdgpu" "$DRIVERS_ROOT/vfio-pci" "$DRIVERS_ROOT/pci-stub" \
  "$DRIVERS_ROOT/snd_hda_intel" "$DRIVERS_ROOT/unexpected-driver"

# No driver symlink: readlink -f would still return a path ending in /driver.
# The fixed helper must instead treat this device as unbound.
if device_driver_name "$DEVICE" "$DEVICES_ROOT" >/dev/null 2>&1; then
  fail 'unbound device was reported as having a driver'
fi
if device_has_expected_host_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'unbound device was reported as having a real host driver'
fi
if device_bound_to_vfio "$DEVICE" "$DEVICES_ROOT"; then
  fail 'unbound device was reported as bound to vfio-pci'
fi
before_untouched="${#released_devices[@]}"
restore_prepare_device "$DEVICE" 0 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq "$before_untouched" ]] \
  || fail 'rollback touched a device that was never changed by the prepare phase'
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 1 && "${released_devices[0]}" == "$DEVICE" ]] \
  || fail 'rollback did not try to restore the host driver for an unbound device'

# A normal host driver must be detected, and rollback must not unbind it.
: > "$DEVICES_ROOT/$DEVICE/driver_override"
ln -s "$DRIVERS_ROOT/amdgpu" "$DEVICES_ROOT/$DEVICE/driver"
[[ "$(device_driver_name "$DEVICE" "$DEVICES_ROOT")" == 'amdgpu' ]] \
  || fail 'amdgpu driver name was not detected'
device_has_expected_host_driver "$DEVICE" "$DEVICES_ROOT" \
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
if device_has_expected_host_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'vfio-pci was incorrectly reported as the expected host driver'
fi
device_bound_to_vfio "$DEVICE" "$DEVICES_ROOT" \
  || fail 'vfio-pci was not detected'
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 2 ]] \
  || fail 'rollback did not try to restore the host driver from vfio-pci'

# pci-stub is not a restored host driver. It must trigger the same recovery
# path instead of suppressing the release warning/fallback.
rm "$DEVICES_ROOT/$DEVICE/driver"
ln -s "$DRIVERS_ROOT/pci-stub" "$DEVICES_ROOT/$DEVICE/driver"
if device_has_expected_host_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'pci-stub was incorrectly accepted as the GPU host driver'
fi
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"
[[ "${#released_devices[@]}" -eq 3 && "${released_devices[2]}" == "$DEVICE" ]] \
  || fail 'rollback did not reprobe the GPU when pci-stub was bound'

# An unknown non-VFIO driver must also be rejected.
rm "$DEVICES_ROOT/$DEVICE/driver"
ln -s "$DRIVERS_ROOT/unexpected-driver" "$DEVICES_ROOT/$DEVICE/driver"
if device_has_expected_host_driver "$DEVICE" "$DEVICES_ROOT"; then
  fail 'unexpected driver was incorrectly accepted as the GPU host driver'
fi

# The HDMI/DisplayPort audio function has its own expected host driver.
: > "$DEVICES_ROOT/$AUDIO_DEVICE/driver_override"
ln -s "$DRIVERS_ROOT/snd_hda_intel" "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
device_has_expected_host_driver "$AUDIO_DEVICE" "$DEVICES_ROOT" \
  || fail 'snd_hda_intel was not recognized as the expected audio driver'
rm "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
ln -s "$DRIVERS_ROOT/amdgpu" "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
if device_has_expected_host_driver "$AUDIO_DEVICE" "$DEVICES_ROOT"; then
  fail 'amdgpu was incorrectly accepted as the HDMI/DP audio driver'
fi
rm "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
ln -s "$DRIVERS_ROOT/pci-stub" "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
if device_has_expected_host_driver "$AUDIO_DEVICE" "$DEVICES_ROOT"; then
  fail 'pci-stub was incorrectly accepted as the HDMI/DP audio driver'
fi
rm "$DEVICES_ROOT/$AUDIO_DEVICE/driver"

# A broken symlink must be treated as unresolved, not as a driver name.
rm "$DEVICES_ROOT/$DEVICE/driver"
ln -s "$DRIVERS_ROOT/missing-driver" "$DEVICES_ROOT/$DEVICE/driver"
if device_driver_name "$DEVICE" "$DEVICES_ROOT" >/dev/null 2>&1; then
  fail 'broken driver symlink was treated as a valid driver'
fi

# A successful reprobe command is not enough: rollback must reject a device
# that remains unbound and return failure to its caller.
MOCK_RELEASE_FAIL_FOR="$DEVICE"
if restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT"; then
  fail 'rollback accepted a GPU that remained unbound after host-driver reprobe'
fi
MOCK_RELEASE_FAIL_FOR=""
restore_prepare_device "$DEVICE" 1 "$DEVICES_ROOT" \
  || fail 'rollback did not accept the GPU after the expected host driver was restored'

# Exercise rollback_prepare with both PCI functions touched. A failed ordinary
# reprobe must invoke the configured fallback and remain visibly unsuccessful
# unless both expected host drivers are present afterward.
rm -f -- "$DEVICES_ROOT/$DEVICE/driver" "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
# These assignments feed rollback_prepare extracted dynamically from the QEMU hook.
# shellcheck disable=SC2034
PREPARE_GPU_PCI_TOUCHED=1
# shellcheck disable=SC2034
PREPARE_GPU_AUDIO_TOUCHED=1
# shellcheck disable=SC2034
PREPARE_DISPLAY_DETACH_ATTEMPTED=0
# shellcheck disable=SC2034
PREPARE_DESKTOP_TOUCHED=1
MOCK_RELEASE_FAIL_FOR="$DEVICE"
MOCK_FALLBACK_RECOVERS=0
MOCK_FALLBACK_CALLS=0
START_HYPRLAND_CALLS=0
MOCK_LOG=()
if rollback_prepare "$DEVICES_ROOT"; then
  fail 'rollback_prepare reported success while the GPU remained unbound'
fi
[[ "$MOCK_FALLBACK_CALLS" -eq 1 ]] \
  || fail 'incomplete ordinary rollback did not invoke the recovery fallback'
[[ "${MOCK_FALLBACK_ARGS[*]}" == "$DEVICE" ]] \
  || fail 'fallback included an audio function that ordinary reprobe had already restored'
[[ "$START_HYPRLAND_CALLS" -eq 1 ]] \
  || fail 'rollback did not attempt recorded desktop-service restoration'
[[ "${MOCK_LOG[*]}" == *"CRITICAL: VFIO preparation rollback is incomplete"* ]] \
  || fail 'incomplete rollback did not emit a critical recovery diagnostic'

# If the opt-in fallback really restores both PCI functions, the final driver
# checks must accept the recovered state and return success.
MOCK_FALLBACK_RECOVERS=1
MOCK_FALLBACK_CALLS=0
START_HYPRLAND_CALLS=0
MOCK_LOG=()
rollback_prepare "$DEVICES_ROOT" \
  || fail 'rollback_prepare rejected devices after the fallback restored both expected drivers'
[[ "$MOCK_FALLBACK_CALLS" -eq 1 ]] \
  || fail 'fallback recovery was not retried for the second rollback attempt'
[[ "${MOCK_FALLBACK_ARGS[*]}" == "$DEVICE" ]] \
  || fail 'successful fallback included an already-restored audio function'
[[ "$(readlink -e -- "$DEVICES_ROOT/$DEVICE/driver")" == "$DRIVERS_ROOT/amdgpu" ]] \
  || fail 'fallback did not restore the GPU to amdgpu'
[[ "$(readlink -e -- "$DEVICES_ROOT/$AUDIO_DEVICE/driver")" == "$DRIVERS_ROOT/snd_hda_intel" ]] \
  || fail 'fallback did not restore the audio function to snd_hda_intel'
[[ "$START_HYPRLAND_CALLS" -eq 1 ]] \
  || fail 'successful rollback did not attempt recorded desktop-service restoration'

MOCK_RELEASE_FAIL_FOR=""
MOCK_FALLBACK_RECOVERS=0

# If only the audio function fails to reprobe, pass only that function to the
# fallback; the healthy display GPU must remain untouched.
# These globals are read by rollback_prepare extracted from the QEMU hook.
# shellcheck disable=SC2034
PREPARE_GPU_PCI_TOUCHED=0
# shellcheck disable=SC2034
PREPARE_GPU_AUDIO_TOUCHED=1
# shellcheck disable=SC2034
PREPARE_DISPLAY_DETACH_ATTEMPTED=0
# shellcheck disable=SC2034
PREPARE_DESKTOP_TOUCHED=0
rm -f -- "$DEVICES_ROOT/$AUDIO_DEVICE/driver"
bind_mock_expected_host_driver "$DEVICE"
MOCK_RELEASE_FAIL_FOR="$AUDIO_DEVICE"
MOCK_FALLBACK_RECOVERS=1
MOCK_FALLBACK_CALLS=0
MOCK_FALLBACK_ARGS=()
rollback_prepare "$DEVICES_ROOT" \
  || fail 'audio-only rollback did not recover with its configured fallback'
[[ "${MOCK_FALLBACK_ARGS[*]}" == "$AUDIO_DEVICE" ]] \
  || fail 'audio-only recovery fallback touched the healthy GPU'
[[ "$(readlink -e -- "$DEVICES_ROOT/$DEVICE/driver")" == "$DRIVERS_ROOT/amdgpu" ]] \
  || fail 'audio-only recovery changed the healthy GPU driver'
[[ "$(readlink -e -- "$DEVICES_ROOT/$AUDIO_DEVICE/driver")" == "$DRIVERS_ROOT/snd_hda_intel" ]] \
  || fail 'audio-only fallback did not restore snd_hda_intel'

MOCK_RELEASE_FAIL_FOR=""
MOCK_FALLBACK_RECOVERS=0
# These globals are read by rollback_prepare extracted from the QEMU hook.
# shellcheck disable=SC2034
PREPARE_GPU_PCI_TOUCHED=0
# shellcheck disable=SC2034
PREPARE_GPU_AUDIO_TOUCHED=0
# shellcheck disable=SC2034
PREPARE_DESKTOP_TOUCHED=0

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
[[ "${MOCK_ACTIVE[polkit.service]}" == "1" ]] || fail 'polkit was not restored to active state'
[[ "${MOCK_ACTIVE[waydroid-container.service]}" == "1" ]] || fail 'Waydroid was not restored to active state'
[[ "${MOCK_ACTIVE[ollama]}" == "0" ]] || fail 'Ollama was started despite being inactive before VM start'
[[ ! -e "$SERVICE_STATE_FILE" ]] || fail 'service-state file was not removed after successful restoration'

# If a service was recorded inactive but becomes active before the stop stage,
# the hook must re-query it, stop it, and preserve the original inactive state.
save_service_state || fail 'could not capture service state before inactive-to-active race test'
MOCK_ACTIVE[ollama]=1
stop_saved_service ollama || fail 'an Ollama service activated after the snapshot was not stopped'
[[ "${MOCK_ACTIVE[ollama]}" == "0" ]] || fail 'the inactive-to-active race left Ollama active during GPU handoff'
restore_saved_services || fail 'inactive-to-active race could not restore captured service state'
[[ "${MOCK_ACTIVE[ollama]}" == "0" ]] || fail 'Ollama was started despite its initially inactive state'

# A service stop failure that leaves the unit active must block GPU handoff.
# The caller checks this status and invokes prepare rollback before unbinding.
save_service_state || fail 'could not capture service state before stop-failure test'
MOCK_STOP_FAIL="waydroid-container.service"
if stop_saved_service waydroid-container.service; then
  fail 'stop_saved_service accepted a failed stop while Waydroid remained active'
fi
[[ "${MOCK_ACTIVE[waydroid-container.service]}" == "1" ]] \
  || fail 'stop-failure mock unexpectedly changed the active Waydroid state'
MOCK_STOP_FAIL=""
restore_saved_services || fail 'failed-stop test could not restore the captured service state'
[[ ! -e "$SERVICE_STATE_FILE" ]] || fail 'state file was not cleared after stop-failure recovery'

# A restore failure must be reported and retain the state file for a retry.
save_service_state || fail 'could not capture service state before restore-failure test'
MOCK_ACTIVE[greetd]=0
MOCK_ACTIVE[ollama]=0
MOCK_ACTIVE[polkit.service]=0
MOCK_ACTIVE[waydroid-container.service]=0
MOCK_START_FAIL="waydroid-container.service"
if restore_saved_services; then
  fail 'restore_saved_services hid a Waydroid start failure'
fi
[[ -e "$SERVICE_STATE_FILE" ]] || fail 'service-state file was deleted after incomplete restoration'
[[ "${MOCK_ACTIVE[waydroid-container.service]}" == "0" ]] \
  || fail 'failed Waydroid start incorrectly changed the mocked unit state'
MOCK_START_FAIL=""
restore_saved_services || fail 'service-state retry failed after a transient Waydroid start failure'
[[ ! -e "$SERVICE_STATE_FILE" ]] || fail 'successful service-state retry did not clear the state file'
[[ "${MOCK_ACTIVE[waydroid-container.service]}" == "1" ]] \
  || fail 'Waydroid did not return to its recorded pre-VM active state'

# If every service was initially inactive, release must not start any of them.
if ! grep -Fq 'for svc in greetd ollama polkit.service waydroid-container.service; do' "$HOOK" \
  || ! grep -Fq 'stop_saved_service "$svc"' "$HOOK" \
  || ! grep -Fq 'aborting before GPU unbind' "$HOOK"; then
  fail 'the VFIO hook must stop and verify each previously active service before GPU unbind'
fi
MOCK_ACTIVE[greetd]=0
MOCK_ACTIVE[ollama]=0
MOCK_ACTIVE[polkit.service]=0
MOCK_ACTIVE[waydroid-container.service]=0
started_count="${#MOCK_STARTED[@]}"
save_service_state || fail 'could not capture all-inactive service state'
restore_saved_services || fail 'all-inactive restoration reported failure'
[[ "${#MOCK_STARTED[@]}" -eq "$started_count" ]] || fail 'a service was started despite all services being initially inactive'

# Saved-state restore is a libvirt XML-filter operation: it must run the same
# VFIO preparation as cold start and return the original XML byte-for-byte.
PREPARE_CALLS=0
MOCK_PREPARE_STATUS=0
prepare_vfio() {
  PREPARE_CALLS=$((PREPARE_CALLS + 1))
  printf '%s\n' 'mock preparation diagnostic that must not enter XML stdout'
  return "$MOCK_PREPARE_STATUS"
}
RESTORE_INPUT="$TMP_DIR/restore-domain.xml"
RESTORE_OUTPUT="$TMP_DIR/restore-output.xml"
printf '%s\n' '<domain><name>win10</name></domain>' > "$RESTORE_INPUT"
restore_vfio_state < "$RESTORE_INPUT" > "$RESTORE_OUTPUT" \
  || fail 'restore hook rejected a successful mocked VFIO preparation'
cmp -s "$RESTORE_INPUT" "$RESTORE_OUTPUT" \
  || fail 'restore hook did not return the input domain XML unchanged'
[[ "$PREPARE_CALLS" -eq 1 ]] \
  || fail 'saved-state restore did not invoke the VFIO prepare path'

# If host preparation fails, restore must abort and emit no XML to libvirt.
PREPARE_CALLS=0
MOCK_PREPARE_STATUS=1
: > "$RESTORE_OUTPUT"
if restore_vfio_state < "$RESTORE_INPUT" > "$RESTORE_OUTPUT"; then
  fail 'restore hook accepted a failed mocked VFIO preparation'
fi
[[ ! -s "$RESTORE_OUTPUT" ]] \
  || fail 'restore hook emitted domain XML after VFIO preparation failed'
[[ "$PREPARE_CALLS" -eq 1 ]] \
  || fail 'restore failure did not invoke the VFIO prepare path exactly once'

# If VFIO preparation succeeds but writing the buffered XML back to libvirt
# fails, the hook must still roll the GPU/desktop preparation back.
REAL_CAT="$(command -v cat)"
MOCK_RESTORE_OUTPUT_FAIL=1
MOCK_RESTORE_OUTPUT_PATH=""
ROLLBACK_CALLS=0
rollback_prepare() {
  ROLLBACK_CALLS=$((ROLLBACK_CALLS + 1))
}
cat() {
  if [[ "$MOCK_RESTORE_OUTPUT_FAIL" == "1" \
    && "${1:-}" == "--" \
    && "${2:-}" == "${RESTORE_XML_FILE:-}" ]]; then
    MOCK_RESTORE_OUTPUT_PATH="$2"
    return 1
  fi
  "$REAL_CAT" "$@"
}
PREPARE_CALLS=0
MOCK_PREPARE_STATUS=0
: > "$RESTORE_OUTPUT"
if restore_vfio_state < "$RESTORE_INPUT" > "$RESTORE_OUTPUT"; then
  fail 'restore accepted a failed XML output operation after VFIO preparation'
fi
[[ "$PREPARE_CALLS" -eq 1 ]] \
  || fail 'output-failure test did not complete VFIO preparation exactly once'
[[ "$ROLLBACK_CALLS" -eq 1 ]] \
  || fail 'restore did not roll back VFIO preparation after XML output failure'
[[ ! -s "$RESTORE_OUTPUT" ]] \
  || fail 'mocked failed XML output unexpectedly emitted data'
[[ -n "$MOCK_RESTORE_OUTPUT_PATH" && ! -e "$MOCK_RESTORE_OUTPUT_PATH" ]] \
  || fail 'temporary restore XML was not removed after output failure'
[[ -z "$RESTORE_XML_FILE" ]] \
  || fail 'restore XML buffer variable was not cleared after output failure'
unset -f cat rollback_prepare

if ! grep -Fq 'if [ "$ACTION" = "restore" ]; then' "$HOOK" \
  || ! grep -Fq 'restore_vfio_state || exit 1' "$HOOK" \
  || ! grep -Fq 'rollback_prepare' "$HOOK"; then
  fail 'the libvirt restore operation is not wired to the VFIO XML-filter handler'
fi

printf 'OK: VFIO driver-state and pre-VM service-state regression tests passed.\n'

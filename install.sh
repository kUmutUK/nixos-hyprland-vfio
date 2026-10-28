#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
info()  { echo -e "${CYAN}[i]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Reject unsupported/live environments before acquiring a lock or requesting
# acknowledgement for this high-risk migration helper.
if ! grep -qi nixos /etc/os-release 2>/dev/null; then
  error "This script must be run on NixOS. No system files have been changed."
fi

# NixOS live installer media exposes the ISO at /iso and its read-only store at
# /nix/.ro-store. This script migrates an already-booted installation and must
# stop before prompting or changing files when run from the live environment.
is_nixos_live_installer() {
  command -v findmnt >/dev/null 2>&1 || return 1
  findmnt -rn -M /iso -t iso9660 >/dev/null 2>&1 && return 0
  findmnt -rn -M /nix/.ro-store -t squashfs >/dev/null 2>&1 && return 0
  return 1
}
if is_nixos_live_installer; then
  error "A NixOS live installer environment was detected. Do not run this migration script from the live ISO; follow INSTALLATION.md for a fresh install or boot the installed NixOS system first. No system files have been changed."
fi

# Fail closed if libvirt cannot confirm that the configured Windows VM is stopped.
# "shut off" is the only accepted state; running/paused/shutting-down/crashed or
# unknown states require the operator to resolve the VM manually before migration.
assert_win10_domain_stopped() {
  local registered_domains state
  if ! command -v virsh >/dev/null 2>&1; then
    error "virsh is required to verify the win10 VM state; no system files have been changed."
  fi
  if ! registered_domains="$(sudo virsh list --all --name)"; then
    error "Could not query libvirt to verify whether win10 is stopped; no system files have been changed."
  fi
  if grep -Fxq win10 <<< "$registered_domains"; then
    if ! state="$(sudo virsh domstate win10 2>/dev/null)"; then
      error "Could not query the registered win10 VM state; no system files have been changed."
    fi
    state="$(printf '%s\n' "$state" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    if [[ "$state" != "shut off" ]]; then
      error "The registered win10 VM is not confirmed shut off (libvirt state: ${state:-unknown}). Run 'sudo virsh shutdown win10', wait until it reports 'shut off', and rerun. No system files have been changed."
    fi
    log "Registered win10 VM is confirmed shut off."
  else
    log "No registered win10 domain exists; there is no running win10 guest to disrupt."
  fi
}

LOCK_HELPER="$REPO_DIR/scripts/installer-lock.sh"
if [[ ! -s "$LOCK_HELPER" ]]; then
  error "Required installer lock helper is missing or empty: $LOCK_HELPER. No system files have been changed."
fi
# shellcheck source=scripts/installer-lock.sh
source "$LOCK_HELPER"
if ! acquire_nixos_installer_lock; then
  error "Could not acquire the installer process lock. No system files have been changed."
fi
TARGET_USER="localhost"
TARGET_HOME="/home/$TARGET_USER"
# Recovery copies stay in the invoking administrator home.
BACKUP_DIR="$HOME/.nixos-config-backup-$(date +%Y%m%d-%H%M%S)"
NIXOS_DIR="/etc/nixos"
NIXOS_FLAKE_DIR="$NIXOS_DIR/nixos"
PATCHED_XML="/var/lib/libvirt/win10.xml"
SNAPSHOT_SUBVOL="/home/.snapshots"
SNAPSHOT_SUBVOL_CREATED=0

REQUIRED_NIXOS_SOURCE_FILES=(configuration.nix home.nix flake.nix flake.lock)

# Reject an incomplete checkout before prompting or touching system state. A skipped
# source file can leave a mixed old/new deployment even when individual copies work.
validate_nixos_source_files() {
  local file source_file
  if [[ ! -d "$REPO_DIR/nixos" ]]; then
    error "Required source directory is missing: $REPO_DIR/nixos. No system files have been changed."
    return 1
  fi
  for file in "${REQUIRED_NIXOS_SOURCE_FILES[@]}"; do
    source_file="$REPO_DIR/nixos/$file"
    if [[ ! -f "$source_file" || ! -s "$source_file" ]]; then
      error "Required NixOS source file is missing or empty: $source_file. No system files have been changed."
      return 1
    fi
  done
}

validate_nixos_source_files

SOURCE_REVISION_FILE="$NIXOS_DIR/.source-revision"
SOURCE_REVISION=""
resolve_source_revision() {
  local revision status
  if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! revision="$(git -C "$REPO_DIR" rev-parse --verify 'HEAD^{commit}')"; then
      error "Could not resolve the source commit; no system files have been changed."
    fi
    if ! status="$(git -C "$REPO_DIR" status --porcelain --untracked-files=all)"; then
      error "Could not verify the source working-tree state; no system files have been changed."
    fi
    if [[ -n "$status" ]]; then
      error "The Git checkout has local or untracked changes. Use a clean checkout or the canonical source ZIP; no system files have been changed."
    fi
  else
    if [[ ! -f "$REPO_DIR/SOURCE_REVISION" || ! -s "$REPO_DIR/SOURCE_REVISION" ]]; then
      error "This source archive has no embedded commit identity. Use a canonical ZIP generated by scripts/package-source-zip.sh; no system files have been changed."
    fi
    if ! revision="$(tr -d '[:space:]' < "$REPO_DIR/SOURCE_REVISION")"; then
      error "Could not read the embedded source commit; no system files have been changed."
    fi
  fi
  if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
    error "The source commit identity is missing or invalid. Use a clean checkout or canonical source ZIP; no system files have been changed."
  fi
  SOURCE_REVISION="$revision"
}
resolve_source_revision

PCI_ADDRESS_HELPERS="$REPO_DIR/scripts/pci-address.sh"
if [[ ! -s "$PCI_ADDRESS_HELPERS" ]]; then
  error "Required PCI address helper is missing or empty: $PCI_ADDRESS_HELPERS. No system files have been changed."
fi
# shellcheck source=scripts/pci-address.sh
source "$PCI_ADDRESS_HELPERS"

require_btrfs_home() {
  local hardware_config="${1:-}"
  if ! command -v findmnt >/dev/null 2>&1; then
    error "findmnt is required to verify Home Snapper mounts; no system files have been changed."
    return 1
  fi
  if [[ -z "$hardware_config" ]]; then
    if [[ -s "$NIXOS_DIR/hardware-configuration.nix" ]]; then
      hardware_config="$NIXOS_DIR/hardware-configuration.nix"
    elif [[ -s "$NIXOS_FLAKE_DIR/hardware-configuration.nix" ]]; then
      hardware_config="$NIXOS_FLAKE_DIR/hardware-configuration.nix"
    else
      hardware_config="$REPO_DIR/nixos/hardware-configuration.nix"
    fi
  fi
  if [[ ! -s "$hardware_config" ]]; then
    error "No readable target hardware-configuration.nix is available for Home Snapper validation: $hardware_config"
    return 1
  fi
  if ! "$PYTHON3" "$REPO_DIR/scripts/check-home-snapper-layout.py" "$hardware_config"; then
    error "Home Snapper preflight rejected the active mount or target UUID/subvolume layout. No system files have been changed."
    return 1
  fi
  if [[ -L "$SNAPSHOT_SUBVOL" ]]; then
    error "$SNAPSHOT_SUBVOL is a symbolic link; refusing to use it as the Home Snapper subvolume."
    return 1
  fi
  if [[ -e "$SNAPSHOT_SUBVOL" ]] && ! sudo btrfs subvolume show "$SNAPSHOT_SUBVOL" >/dev/null 2>&1; then
    error "$SNAPSHOT_SUBVOL exists but is not a Btrfs subvolume; inspect it manually before installation."
    return 1
  fi
}

echo ""
echo -e "${CYAN}==============================================================${NC}"
echo -e "${CYAN}   NixOS Hyprland + VFIO — High-Risk Migration Helper${NC}"
echo -e "${CYAN}==============================================================${NC}"
echo ""

echo -e "${RED}${BOLD}WARNING: ADVANCED, HIGH-RISK MIGRATION SCRIPT${NC}"
echo ""
warn "RECOMMENDED APPROACH: Follow the manual migration steps in README.md first."
warn "This script is not for a first-time NixOS installation or disk partitioning."
warn "There is no dry-run mode; after acknowledgement, this script changes system files."
info "Copies/replaces NixOS and Home Manager source files plus the VFIO hook source under /etc/nixos/nixos/hooks. It synchronizes VM XML only when a registered win10 domain or deployed XML already exists; a genuinely new VM is initialized during the documented VM-preparation step."
info "The active libvirt hook is generated by NixOS and is not refreshed until a successful nixos-rebuild switch."
info "The written VM XML is not applied with virsh define automatically; review and run the printed command yourself."
info "Incorrect PCI addresses, UUID/mount settings, or VM XML can make the host unbootable or the VM unusable."
info "Backup and rollback are best-effort; they do not replace a full system backup or a tested recovery method."
info "Existing installer backups are never pruned automatically; each run uses a separate private backup directory."
echo ""
echo -e "${YELLOW}POSSIBLE RISKS:${NC}"
echo "  - NixOS may fail to boot or become unstable."
echo "  - Display output may be lost during GPU passthrough and the desktop may not recover."
echo "  - Incorrect UUID, filesystem, or mount settings may break boot."
echo "  - Incorrect PCI addresses can make the VM inaccessible; unsupported existing XML is rejected for manual review."
echo "  - Kernel, driver, ROCm, or hardware incompatibility."
echo "  - Data loss or difficult recovery after partial rollback or inadequate backups."
echo ""
echo -e "${YELLOW}BEFORE YOU CONTINUE:${NC}"
echo "  - Back up important personal data and the existing NixOS/VM configuration separately."
echo "  - Review this script and every configuration file it will change."
echo "  - Verify hardware/PCI/IOMMU compatibility; an acknowledgement is not a compatibility test."
echo "  - Keep a physical TTY or working recovery environment available."
echo "  - Verify hardware-configuration.nix, system.stateVersion, and home.stateVersion."
echo ""
info "The script does not automatically rebuild/activate NixOS, define the updated VM XML with virsh, or reboot."
info "Read README.md and DISCLAIMER.md for more information."
echo ""
read -rp "Do you accept using this high-risk automated migration helper instead of manual installation? Type exactly 'I ACCEPT THE RISKS' to continue: " confirm
[[ "$confirm" != "I ACCEPT THE RISKS" ]] && {
info "Installation cancelled; no system configuration files were changed."
exit 0
}

step "Preflight checks"
# The deployment target is /etc/nixos/nixos. A checkout anywhere inside
# /etc/nixos can overlap its source and deployment paths, not only when the
# repository root is exactly /etc/nixos. Resolve physical paths before checking
# the boundary so symlinked paths cannot bypass this guard.
ensure_repo_outside_deployment_target() {
  local repo_dir="$1" nixos_dir="$2" nixos_dir_real
  [[ -d "$nixos_dir" ]] || return 0
  nixos_dir_real="$(cd "$nixos_dir" && pwd -P)" || error "Could not resolve deployment directory: $nixos_dir"
  case "$repo_dir" in
    "$nixos_dir_real"|"$nixos_dir_real"/*)
      error "Do not run the repository from /etc/nixos itself or any directory beneath it. Keep the checkout outside /etc/nixos (for example ~/nixos-hyprland-vfio) so source files cannot overlap the deployment target."
      ;;
  esac
}
ensure_repo_outside_deployment_target "$REPO_DIR" "$NIXOS_DIR"
if [[ $EUID -eq 0 ]]; then
  error "Do not run as root. Use a normal user with sudo privileges."
fi
# Verify now to stop early, then repeat at the transaction boundary to narrow
# the window in which another process could start the guest after this check.
assert_win10_domain_stopped
if ! command -v lspci &>/dev/null; then
  error "pciutils not found. Install it temporarily: nix-shell -p pciutils"
fi
if ! command -v python3 &>/dev/null; then
  error "python3 is missing. Return to the repository and rerun with: nix-shell -p python3 --run 'bash ./install.sh'"
fi
# Capture the resolved interpreter before privileged operations. In a temporary
# nix-shell this may live under /nix/store and not be present in sudo secure_path.
PYTHON3="$(command -v python3)"
log "Environment OK (Python: ${PYTHON3})."

# This hash is for the local `localhost` account, not SSH password
# authentication. Check it before system mutation, but do not abort: the manual
# checklist can create/fix it before the new configuration is activated.
check_local_password_hash() {
  local hash_file="$1" metadata
  if [[ ! -s "$hash_file" ]]; then
    warn "Local localhost account password hash is missing or empty: ${hash_file}."
    return 1
  fi
  if ! metadata="$(stat -c '%U:%G:%a' -- "$hash_file" 2>/dev/null)"; then
    warn "Could not inspect local account password-hash metadata: ${hash_file}."
    return 1
  fi
  if [[ "$metadata" != "root:root:600" ]]; then
    warn "Local account password hash must be owned by root:root with mode 0600; found ${metadata}."
    return 1
  fi
  log "Local localhost account password hash exists with root:root mode 0600."
  return 0
}

if ! check_local_password_hash "$NIXOS_DIR/hashedPassword"; then
  warn "Fix /etc/nixos/hashedPassword using the manual checklist before rebuilding; this file supplies the local localhost account password and does not enable SSH password login. SSH remains public-key-only."
fi

# Validate the proposed host mount layout and UUIDs before backups or any mutation.
HOME_SNAPPER_HW_CONFIG=""
if [[ -s "$NIXOS_DIR/hardware-configuration.nix" ]]; then
  HOME_SNAPPER_HW_CONFIG="$NIXOS_DIR/hardware-configuration.nix"
elif [[ -s "$NIXOS_FLAKE_DIR/hardware-configuration.nix" ]]; then
  HOME_SNAPPER_HW_CONFIG="$NIXOS_FLAKE_DIR/hardware-configuration.nix"
else
  HOME_SNAPPER_HW_CONFIG="$REPO_DIR/nixos/hardware-configuration.nix"
fi
require_btrfs_home "$HOME_SNAPPER_HW_CONFIG"

# ─── Hardware detection ───────────────────────────────────
step "Hardware detection"

if grep -qi "GenuineIntel" /proc/cpuinfo; then
  CPU_VENDOR="intel"
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
  CPU_VENDOR="amd"
else
  CPU_VENDOR="unknown"
fi
log "CPU: $CPU_VENDOR"

# GPU vendor is determined only after the user selects a concrete PCI address.
# Do not infer it from the first lspci display adapter: multi-GPU systems often
# list an iGPU before the dedicated passthrough GPU.
GPU_VENDOR="unknown"
echo ""
# ─── User inputs ─────────────────────────────────────────
step "Configuration inputs"

echo "Detected VGA devices:"
lspci -nn | grep -iE "vga|3d|display" | sed 's/^/  /'
echo ""
read -rp "Enter GPU VGA PCI address (e.g. 0000:0b:00.0): " gpu_pci
read -rp "Enter GPU Audio PCI address (e.g. 0000:0b:00.1): " gpu_audio

# Reject malformed addresses and invalid PCI function numbers before writing
# hook/configuration data. The shared helper accepts uppercase input, while the
# addresses are normalized below before they are used as sysfs paths.
iommu_group_number() {
  local link="$1" resolved group_num
  [[ -e "$link" ]] || return 0
  resolved="$(readlink -e -- "$link" 2>/dev/null)" || return 0
  [[ "$resolved" =~ ^/sys/kernel/iommu_groups/[0-9]+$ && -d "$resolved" ]] || return 0
  group_num="${resolved##*/}"
  [[ "$group_num" =~ ^[0-9]+$ ]] || return 0
  printf '%s\n' "$group_num"
}

for _try in 1 2 3; do
  if valid_pci_address "$gpu_pci"; then break; fi
  warn "'$gpu_pci' is not a valid PCI address; expected format: 0000:0b:00.0"
  if [ "$_try" -lt 3 ]; then read -rp "GPU PCI address: " gpu_pci; fi
done
valid_pci_address "$gpu_pci" || error "Invalid GPU PCI address after 3 attempts; aborting installation."

for _try in 1 2 3; do
  if valid_pci_address "$gpu_audio"; then break; fi
  warn "'$gpu_audio' is not a valid PCI address; expected format: 0000:0b:00.1"
  if [ "$_try" -lt 3 ]; then read -rp "GPU audio PCI address: " gpu_audio; fi
done
valid_pci_address "$gpu_audio" || error "Invalid GPU audio PCI address after 3 attempts; aborting installation."

# Linux sysfs exposes PCI BDF names in lowercase. Normalize both values once so
# every later sysfs, lspci, hook, and XML check uses the same canonical form.
gpu_pci="$(normalize_pci_address "$gpu_pci")"
gpu_audio="$(normalize_pci_address "$gpu_audio")"

for addr in "$gpu_pci" "$gpu_audio"; do
  if [ ! -e "/sys/bus/pci/devices/${addr}" ]; then
    error "PCI device not found: $addr. Check the address reported by lspci -nn."
  fi
done

# Validate PCI class codes as well as address syntax/existence. This prevents
# an existing but unrelated device (for example, a NIC) being passed to VFIO.
# `lspci -Dn` prints: <domain:BDF> <class-code>: <vendor>:<device> ...
pci_class_code() {
  local addr="$1" line class_code
  line="$(lspci -Dn -s "$addr" 2>/dev/null)" || return 1
  [ -n "$line" ] || return 1
  class_code="$(awk 'NR == 1 { print $2; exit }' <<< "$line")"
  class_code="${class_code%:}"
  [[ "$class_code" =~ ^[0-9a-fA-F]{4}$ ]] || return 1
  printf '%s\n' "${class_code,,}"
}

gpu_class_code="$(pci_class_code "$gpu_pci")" || error "Could not verify GPU PCI class with lspci: $gpu_pci"
case "$gpu_class_code" in
  0300|0302|0380) ;;
  *) error "Selected GPU address is not a display controller (PCI class $gpu_class_code): $gpu_pci — enter the VGA/3D/display controller address." ;;
esac

audio_class_code="$(pci_class_code "$gpu_audio")" || error "Could not verify GPU audio PCI class with lspci: $gpu_audio"
case "$audio_class_code" in
  0401|0403) ;;
  *) error "Selected audio address is not an audio controller (PCI class $audio_class_code): $gpu_audio — enter the GPU HDMI/DisplayPort audio-function address." ;;
esac
log "PCI classes verified: GPU=$gpu_class_code, Audio=$audio_class_code"

# The GPU display function and its HDMI/DisplayPort audio function must belong
# to the same physical PCI device (domain:bus:slot).
gpu_slot="${gpu_pci%.*}"
audio_slot="${gpu_audio%.*}"
if [[ "${gpu_slot,,}" != "${audio_slot,,}" ]]; then
  error "The GPU and HDMI/DP audio function must share the same PCI domain:bus:slot: GPU=$gpu_pci, Audio=$gpu_audio"
fi
log "GPU/audio functions belong to the same PCI device: $gpu_slot"

# Classify the device the user actually selected, not the first display device
# reported by lspci. Keep the full PCI address in the selection and validation.
gpu_line="$(lspci -nn -s "$gpu_pci" 2>/dev/null || true)"
if echo "$gpu_line" | grep -qiE "AMD|ATI|Radeon"; then
  GPU_VENDOR="amd"
elif echo "$gpu_line" | grep -qiE "NVIDIA|GeForce"; then
  GPU_VENDOR="nvidia"
elif echo "$gpu_line" | grep -qi "Intel"; then
  GPU_VENDOR="intel"
else
  GPU_VENDOR="unknown"
fi
log "Selected GPU: $GPU_VENDOR"
echo -e "  ${CYAN}$gpu_line${NC}"
log "GPU PCI: $gpu_pci / Audio: $gpu_audio (format and sysfs presence verified)"

if [[ "$CPU_VENDOR" != "amd" || "$GPU_VENDOR" != "amd" ]]; then
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  warn "Unsupported hardware: this repository's active configuration targets AMD CPU + AMD GPU only."
  if [[ "$CPU_VENDOR" != "amd" ]]; then
    echo "  - CPU detected: ${CPU_VENDOR}; this configuration uses AMD microcode, kvm-amd, and AMD-specific kernel settings."
  fi
  if [[ "$GPU_VENDOR" != "amd" ]]; then
    echo "  - GPU detected: ${GPU_VENDOR}; this configuration assumes amdgpu/RADV and AMD-specific Vulkan/ROCm settings."
  fi
  echo "  - No hardware-specific configuration will be deployed. Adapt and validate the NixOS files manually first."
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  error "Installer stopped before changing system configuration because the detected hardware is unsupported."
fi

# Vendor detection alone is not proof of compatibility. The configuration is
# documented against RX 6700 XT / Navi 22; other AMD models need separate review.
echo ""
warn "GPU compatibility must be verified separately."
echo "  Documented target: AMD Radeon RX 6700 XT (Navi 22)."
echo "  For other AMD cards, verify IOMMU groups, reset behavior, and the ROCm gfx override separately."
read -rp "Have you verified that this model is compatible? Type exactly 'yes' to continue: " gpu_compat_confirm
if [[ "$gpu_compat_confirm" != "yes" ]]; then
  error "GPU compatibility was not acknowledged; no system files were changed."
fi

# ─── IOMMU group preflight ─────────────────────────────────
step "IOMMU group check"
gpu_iommu_dir="/sys/bus/pci/devices/${gpu_pci}/iommu_group"
audio_iommu_dir="/sys/bus/pci/devices/${gpu_audio}/iommu_group"
gpu_grp="$(iommu_group_number "$gpu_iommu_dir")"
audio_grp="$(iommu_group_number "$audio_iommu_dir")"

show_iommu_group() {
  local group_num="$1" dev dev_addr
  [ -n "$group_num" ] || return 0
  info "IOMMU group ${group_num} members:"
  for dev in /sys/kernel/iommu_groups/"${group_num}"/devices/*; do
    [ -e "$dev" ] || continue
    dev_addr="$(basename "$dev")"
    lspci -nns "$dev_addr" | sed 's/^/    /'
  done
}

# Do not deploy a VFIO configuration unless both selected PCI functions have
# real IOMMU groups. Continuing without this information would make the safety
# of the device handoff impossible to establish.
if [ -z "$gpu_grp" ]; then
  error "Could not resolve the GPU IOMMU group at ${gpu_iommu_dir}. Enable IOMMU/AMD-Vi in BIOS/UEFI, reboot into NixOS, verify /sys/kernel/iommu_groups, and rerun the installer. No configuration files have been changed."
fi
if [ -z "$audio_grp" ]; then
  error "Could not resolve the GPU audio-function IOMMU group at ${audio_iommu_dir}. Enable IOMMU/AMD-Vi in BIOS/UEFI, reboot into NixOS, verify /sys/kernel/iommu_groups, and rerun the installer. No configuration files have been changed."
fi

info "GPU ($gpu_pci) IOMMU group: $gpu_grp"
show_iommu_group "$gpu_grp"
if [ "$audio_grp" != "$gpu_grp" ]; then
  warn "Audio function ($gpu_audio) is in a different IOMMU group: $audio_grp"
  show_iommu_group "$audio_grp"
fi
echo ""
warn "If either group contains devices other than GPU (${gpu_pci}) and audio function (${gpu_audio}),"
warn "those devices may not be safely isolated unless additional measures are taken."
warn "ACS override is not enabled by default and does not guarantee safe isolation."
read -rp "Continue only after reviewing both groups (type yes to confirm): " iommu_confirm
[[ "$iommu_confirm" != "yes" ]] && { info "Aborted."; exit 0; }

echo ""
# Leave the monitor output empty by default and auto-detect it only when a real
# connected output is found. Hard-coding DP-3 can silently break mpvpaper on
# systems with a different monitor layout.
monitor_output=""
if command -v hyprctl &>/dev/null 2>&1 && hyprctl activeworkspace &>/dev/null 2>&1; then
  monitor_output=$(hyprctl monitors 2>/dev/null | grep -oPm1 '^Monitor \K\S+' || true)
  if [[ -n "$monitor_output" ]]; then
    log "Active Hyprland monitor: $monitor_output"
  fi
fi
if [[ -z "$monitor_output" ]] && [ -d /sys/class/drm ]; then
  for card in /sys/class/drm/card*-*; do
    status=$(cat "$card/status" 2>/dev/null || true)
    if [ "$status" = "connected" ]; then
      monitor_output=$(basename "$card" | sed 's/card[0-9]*-//')
      if [[ -n "$monitor_output" ]]; then
        log "DRM connected monitor: $monitor_output"
        break
      fi
    fi
  done
fi
trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read -rp "Monitor output name (for Hyprland monitor rule and mpvpaper wallpaper) [${monitor_output:-not detected}]: " input_mon
input_mon="$(trim_whitespace "$input_mon")"
if [[ -n "$input_mon" ]]; then
  monitor_output="$input_mon"
fi
while [[ -z "${monitor_output//[[:space:]]/}" ]]; do
  warn "Monitor output name cannot be empty. Find the exact name with: hyprctl monitors"
  read -rp "Enter a non-empty monitor output name (e.g. DP-3): " input_mon
  input_mon="$(trim_whitespace "$input_mon")"
  if [[ -n "$input_mon" ]]; then
    monitor_output="$input_mon"
  fi
done

echo ""
read -rp "Hyprland monitor mode (preferred or WIDTHxHEIGHT[@HZ]) [preferred]: " hypr_mon_mode
hypr_mon_mode="${hypr_mon_mode:-preferred}"
while [[ ! "$hypr_mon_mode" =~ ^(preferred|[0-9]{3,5}x[0-9]{3,5}(@[0-9]{1,3}([.][0-9]{1,3})?)?)$ ]]; do
  warn "Invalid monitor mode. Use 'preferred' or a mode such as 2560x1440@170."
  read -rp "Hyprland monitor mode [preferred]: " hypr_mon_mode
  hypr_mon_mode="${hypr_mon_mode:-preferred}"
done

echo ""
wallpaper_video="$TARGET_HOME/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4"
expand_home_prefix() {
  local value="$1"
# shellcheck disable=SC2088
# Intentional: match literal "~/" prefix from user input; do not expand.
local tilde_prefix='~/'
  case "$value" in
    '~')                  printf '%s' "$TARGET_HOME" ;;
    "$tilde_prefix"*)    printf '%s/%s' "$TARGET_HOME" "${value:2}" ;;
    '~'*)                 error "Named-user tilde paths are not supported; use an absolute path or ~/relative/path." ;;
    *)                    printf '%s' "$value" ;;
  esac
}
read -rp "Wallpaper video path [${wallpaper_video}]: " input_video
input_video="$(trim_whitespace "$input_video")"
if [[ -n "$input_video" ]]; then
  wallpaper_video="$(expand_home_prefix "$input_video")"
fi

echo ""
# Fix: the previous defaults exposed the maintainer's real identity. Pressing
# Enter would attribute commits to someone else. Use the same neutral placeholders
# as home.nix: changeme / you@example.com.
read -rp "Git user name [changeme]: " git_name
git_name="${git_name:-changeme}"
read -rp "Git email [you@example.com]: " git_email
git_email="${git_email:-you@example.com}"

# Treat the deployed NixOS files, VFIO hook, machine-specific hardware file, and
# VM XML as one transaction. Refuse symlinked deployment paths: later copy/atomic-
# replace operations have different symlink semantics and could silently replace
# a link or write through it. Inspect and resolve such paths manually first.
TRANSACTION_PATHS=(
  "$NIXOS_FLAKE_DIR/configuration.nix"
  "$NIXOS_FLAKE_DIR/home.nix"
  "$NIXOS_FLAKE_DIR/flake.nix"
  "$NIXOS_FLAKE_DIR/flake.lock"
  "$NIXOS_FLAKE_DIR/hooks"
  "$NIXOS_FLAKE_DIR/hardware-configuration.nix"
  "$SOURCE_REVISION_FILE"
  "$PATCHED_XML"
)
assert_no_symlink_transaction_targets() {
  local target
  if [[ -L "$NIXOS_FLAKE_DIR" ]]; then
    error "Deployment directory $NIXOS_FLAKE_DIR is a symbolic link. Resolve it manually before installation."
    return 1
  fi
  for target in "${TRANSACTION_PATHS[@]}"; do
    if [[ -L "$target" ]]; then
      error "Deployment target $target is a symbolic link (including a dangling link). Resolve it manually before installation."
      return 1
    fi
  done
}
assert_no_symlink_transaction_targets

# The deployment directory itself is not a transaction target. Remember whether
# it existed before this run so rollback can remove it only when this installer
# created it and all managed targets have been cleaned up.
if [[ -e "$NIXOS_FLAKE_DIR" ]]; then
  NIXOS_FLAKE_DIR_EXISTED=1
else
  NIXOS_FLAKE_DIR_EXISTED=0
fi

declare -A TRANSACTION_EXISTED=()

# ─── Backup ──────────────────────────────────────────────
step "Backing up current configurations"
if [[ -e "$BACKUP_DIR" || -L "$BACKUP_DIR" ]]; then
    error "Backup path already exists; refusing to reuse it: $BACKUP_DIR"
fi
# Recheck immediately before the first filesystem mutation; interactive hardware
# prompts may have left time for another process to start the VM.
assert_win10_domain_stopped
mkdir -m 700 -- "$BACKUP_DIR"
for src in "$TARGET_HOME/.config/hypr" "$TARGET_HOME/.config/waybar" "$TARGET_HOME/.config/gtk-3.0" "$TARGET_HOME/.config/gtk-4.0" \
            "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/home.nix" \
            "$NIXOS_FLAKE_DIR/flake.nix" "$NIXOS_FLAKE_DIR/flake.lock" \
            "$NIXOS_FLAKE_DIR/hooks" \
            "$NIXOS_DIR/hardware-configuration.nix" \
            "$NIXOS_FLAKE_DIR/hardware-configuration.nix" \
            "$SOURCE_REVISION_FILE" "$PATCHED_XML"; do
    if [[ -e "$src" || -L "$src" ]]; then
        # Full source paths avoid collisions between equal basenames. `cp -a`
        # preserves symlink identity and metadata in the recovery copy instead
        # of dereferencing links and turning their targets into ordinary files.
        backup_name="$(printf '%s' "$src" | tr '/' '_')"
        if cp -a -- "$src" "$BACKUP_DIR/$backup_name" 2>/dev/null; then
            log "Backed up: $backup_name"
        else
            warn "Backup FAILED for: $src"
            warn "No existing configuration has been replaced yet; aborting for safety."
            exit 1
        fi
    fi
done
log "Backup saved to $BACKUP_DIR"

# Any later command failure restores the targets that existed before this run;
# targets created by this run are removed. The backup remains for manual recovery.
for target in "${TRANSACTION_PATHS[@]}"; do
  if [ -e "$target" ] || [ -L "$target" ]; then
    TRANSACTION_EXISTED["$target"]=1
  else
    TRANSACTION_EXISTED["$target"]=0
  fi
done
TRANSACTION_ACTIVE=0

transaction_backup_path() {
  printf '%s/%s' "$BACKUP_DIR" "$(printf '%s' "$1" | tr '/' '_')"
}

rollback_deployment() {
  local exit_status="$1" target failed=0 backup_path parent
  trap - EXIT
  if [ "$exit_status" -ne 0 ] && [ "${TRANSACTION_ACTIVE:-0}" = "1" ]; then
    warn "Installer failed after deployment began; restoring the prior NixOS/VFIO/XML files."
    for target in "${TRANSACTION_PATHS[@]}"; do
      if [ "${TRANSACTION_EXISTED[$target]:-0}" = "1" ]; then
        backup_path="$(transaction_backup_path "$target")"
        if [ ! -e "$backup_path" ] && [ ! -L "$backup_path" ]; then
          warn "Rollback backup missing for $target ($backup_path); manual recovery may be needed."
          failed=1
          continue
        fi
        parent="$(dirname "$target")"
        if ! sudo mkdir -p -- "$parent" || ! sudo rm -rf -- "$target" || ! sudo cp -a -- "$backup_path" "$target"; then
          warn "Rollback failed while restoring $target; restore it manually from $BACKUP_DIR."
          failed=1
          continue
        fi
        # These system configuration paths are normally root-owned. Do not let
        # recursive chown follow a symlink if one appeared after preflight.
        if [[ -L "$target" ]]; then
          if ! sudo chown -h root:root -- "$target"; then
            warn "Could not restore symlink ownership for $target."
            failed=1
          fi
        elif ! sudo chown -R root:root -- "$target"; then
          warn "Could not restore root ownership for $target."
          failed=1
        fi
      else
        if ! sudo rm -rf -- "$target"; then
          warn "Could not remove newly created target $target during rollback."
          failed=1
        fi
      fi
    done

    # Remove the deployment directory only if it did not exist before this run.
    # Use rmdir rather than rm -rf: anything untracked or added concurrently must
    # be retained, even if that means the rollback is reported as incomplete.
    if [[ "${NIXOS_FLAKE_DIR_EXISTED:-1}" = "0" && -d "$NIXOS_FLAKE_DIR" ]]; then
      if sudo rmdir -- "$NIXOS_FLAKE_DIR"; then
        warn "Removed the empty deployment directory created by this failed installer run."
      else
        warn "Retained the newly created deployment directory because it is not empty or could not be removed: $NIXOS_FLAKE_DIR"
        failed=1
      fi
    fi

    if [ "${SNAPSHOT_SUBVOL_CREATED:-0}" = "1" ]; then
      if sudo btrfs subvolume show "$SNAPSHOT_SUBVOL" >/dev/null 2>&1; then
        local snapshot_contents
        if snapshot_contents="$(sudo find "$SNAPSHOT_SUBVOL" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"; then
          if [ -z "$snapshot_contents" ]; then
            if sudo btrfs subvolume delete "$SNAPSHOT_SUBVOL"; then
              warn "Removed the empty snapshot subvolume created by this failed installer run."
              SNAPSHOT_SUBVOL_CREATED=0
            else
              warn "Could not remove the empty snapshot subvolume created by this run: $SNAPSHOT_SUBVOL"
              failed=1
            fi
          else
            warn "Retained the snapshot subvolume because it is no longer empty: $SNAPSHOT_SUBVOL"
            failed=1
          fi
        else
          warn "Could not inspect the snapshot subvolume; retaining it for safety: $SNAPSHOT_SUBVOL"
          failed=1
        fi
      elif [ ! -e "$SNAPSHOT_SUBVOL" ]; then
        SNAPSHOT_SUBVOL_CREATED=0
      else
        warn "Could not verify the snapshot subvolume during rollback; leaving it untouched: $SNAPSHOT_SUBVOL"
        failed=1
      fi
    fi
    if [ "$failed" = "0" ]; then
      warn "Rollback completed. Backup retained at $BACKUP_DIR."
    else
      warn "Rollback was incomplete. Inspect $BACKUP_DIR and the messages above before rebuilding."
    fi
  fi
  exit "$exit_status"
}
trap 'rollback_deployment "$?"' EXIT

# Recovery backups are intentionally never pruned automatically. An interrupted
# migration or delayed discovery of a problem must not lose an older restore point.
# After the host, desktop, and VM have been verified, the user may inspect and
# manually delete a specific backup directory if desired.

# Read stateVersion from the existing destination before replacing files.
# stateVersion is a compatibility baseline, not the target NixOS release; it
# must not silently advance when this repository is copied over an older system.
extract_state_version() {
  python3 - "$1" "$2" <<'PY_STATE_VERSION'
import re
import sys
from pathlib import Path

path, setting = sys.argv[1], sys.argv[2]
try:
    content = Path(path).read_text(encoding="utf-8")
except (OSError, UnicodeError):
    # The file exists but cannot be read/decoded: treat this as an ambiguous
    # source, not as a missing assignment that permits fallback to stale data.
    raise SystemExit(2)
pattern = re.compile(
    r"^\s*" + re.escape(setting) +
    r'\s*=\s*(?:lib\.mkDefault\s*)?"(\d{2}\.\d{2})"\s*;',
    re.MULTILINE,
)
assignment = re.compile(r"^\s*" + re.escape(setting) + r"\s*=", re.MULTILINE)
if not assignment.search(content):
    raise SystemExit(1)
assignments = assignment.findall(content)
values = pattern.findall(content)
# Exit 2 distinguishes a present but non-literal/duplicated setting from a
# file that does not define this setting. The count must match exactly; one
# valid literal plus one non-literal assignment is still ambiguous.
if len(assignments) != 1 or len(values) != 1:
    raise SystemExit(2)
print(values[0])
PY_STATE_VERSION
}

read_state_version() {
  local setting="$1" candidate value="" selected_value="" selected_source=""
  local found_file=0 conflict=0 ambiguous=0 parse_status
  local -a observed=()
  shift
  for candidate in "$@"; do
    [ -f "$candidate" ] || continue
    found_file=1
    if value="$(extract_state_version "$candidate" "$setting")"; then
      observed+=("$candidate=$value")
      if [ -z "$selected_value" ]; then
        selected_value="$value"
        selected_source="$candidate"
      elif [ "$value" != "$selected_value" ]; then
        conflict=1
      fi
    else
      parse_status=$?
      if [ "$parse_status" -eq 2 ]; then
        ambiguous=1
        observed+=("$candidate=<ambiguous or non-literal>")
      fi
    fi
  done

  # Multiple existing files can be stale copies of one another. Never silently
  # choose the first version when another candidate disagrees or cannot be
  # parsed unambiguously; require the operator to review the active config.
  if [ "$conflict" = "1" ] || [ "$ambiguous" = "1" ] || { [ "$found_file" = "1" ] && [ -z "$selected_value" ]; }; then
    warn "Cannot safely infer ${setting} from existing files: ${observed[*]:-no literal value found}."
    read -rp "Review the active configuration and enter its existing ${setting} value (e.g. 24.11; leave blank to cancel): " value
    [[ "$value" =~ ^[0-9]{2}\.[0-9]{2}$ ]] || error "${setting} could not be validated; installation stopped before files were changed."
    STATE_VERSION_VALUE="$value"
    STATE_VERSION_SOURCE="user input after ambiguous/conflicting sources"
  elif [ -n "$selected_value" ]; then
    STATE_VERSION_VALUE="$selected_value"
    STATE_VERSION_SOURCE="$selected_source"
  else
    # A genuinely new installation has no existing compatibility baseline;
    # leave the repository template's documented default unchanged.
    STATE_VERSION_VALUE=""
    STATE_VERSION_SOURCE="repository default (new install)"
  fi
}

# ─── File copy ──────────────────────────────────────────
step "Copying configuration files"
[[ ! -d "$REPO_DIR/nixos" ]] && error "nixos/ directory not found in repository."

SYSTEM_STATE_VERSION=""
HOME_STATE_VERSION=""
read_state_version "system.stateVersion" "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_DIR/configuration.nix"
SYSTEM_STATE_VERSION="$STATE_VERSION_VALUE"
log "system.stateVersion source: $STATE_VERSION_SOURCE${SYSTEM_STATE_VERSION:+ (value $SYSTEM_STATE_VERSION)}"
read_state_version "home.stateVersion" "$NIXOS_FLAKE_DIR/home.nix" "$NIXOS_DIR/home.nix" "$TARGET_HOME/.config/home-manager/home.nix"
HOME_STATE_VERSION="$STATE_VERSION_VALUE"
log "home.stateVersion source: $STATE_VERSION_SOURCE${HOME_STATE_VERSION:+ (value $HOME_STATE_VERSION)}"

# Start the transaction before the first filesystem mutation so a partial
# mkdir failure is covered by the EXIT rollback handler too.
TRANSACTION_ACTIVE=1
# Re-check the complete set after the interactive planning phase and while rollback is
# active. A source that disappeared must not be silently skipped during deployment.
validate_nixos_source_files
sudo mkdir -p "$NIXOS_FLAKE_DIR"
for f in "${REQUIRED_NIXOS_SOURCE_FILES[@]}"; do
    source_file="$REPO_DIR/nixos/$f"
    if [[ ! -f "$source_file" || ! -s "$source_file" ]]; then
        error "Required NixOS source file disappeared or became empty during deployment: $source_file"
    fi
    sudo cp "$source_file" "$NIXOS_FLAKE_DIR/$f"
    log "Copied $f"
done

# The marker participates in the same rollback transaction as the deployed files.
printf '%s\n' "$SOURCE_REVISION" | sudo tee "$SOURCE_REVISION_FILE" >/dev/null
sudo chmod 0644 "$SOURCE_REVISION_FILE"
log "Recorded deployed source revision $SOURCE_REVISION."

# Apply the previously discovered compatibility baselines to the freshly
# copied template. The template assignments are expected to occur exactly once.
apply_state_version() {
  local file="$1" setting="$2" value="$3" escaped_setting count
  [ -n "$value" ] || return 0
  case "$setting" in
    system.stateVersion) escaped_setting='system\.stateVersion' ;;
    home.stateVersion) escaped_setting='home\.stateVersion' ;;
    *) error "Unsupported stateVersion setting: $setting" ;;
  esac
  count="$(sudo grep -Ec "^[[:space:]]*${escaped_setting}[[:space:]]*=" "$file" || true)"
  [ "$count" = "1" ] || error "${file} does not have exactly one ${setting} assignment; automatic update is unsafe. Backup: $BACKUP_DIR"
  sudo sed -i -E "s|^([[:space:]]*${escaped_setting}[[:space:]]*=[[:space:]]*)\"[^\"]+\";|\\1\"${value}\";|" "$file"
  sudo grep -Eq "^[[:space:]]*${escaped_setting}[[:space:]]*=[[:space:]]*\"${value}\";" "$file" ||
    error "${setting} could not be preserved; do not rebuild the configuration. Backup: $BACKUP_DIR"
  log "Preserved ${setting}=${value} in $file"
}
apply_state_version "$NIXOS_FLAKE_DIR/configuration.nix" "system.stateVersion" "$SYSTEM_STATE_VERSION"
apply_state_version "$NIXOS_FLAKE_DIR/home.nix" "home.stateVersion" "$HOME_STATE_VERSION"

# Fix: hardware-configuration.nix was only warned about, never staged at the
# flake-relative path imported by configuration.nix. The installer now preserves
# a machine-specific local copy when one exists; repository hardware values are
# never treated as valid for the current machine.
HW_CONFIG_RETAINED=0
if [ -f "$NIXOS_DIR/hardware-configuration.nix" ]; then
    hw_source="$NIXOS_DIR/hardware-configuration.nix"
    hw_target="$NIXOS_FLAKE_DIR/hardware-configuration.nix"

    if [ -e "$hw_target" ] && [ ! -f "$hw_target" ]; then
        error "${hw_target} exists but is not a regular file; inspect it manually."
    fi

    if [ -f "$hw_target" ] && ! sudo cmp -s -- "$hw_source" "$hw_target"; then
        warn "The existing flake hardware-configuration.nix differs from the top-level file."
        warn "The current file may contain intentional machine-specific mount/UUID settings."
        echo "--- diff (existing flake file -> top-level file) ---"
        sudo diff -u -- "$hw_target" "$hw_source" || true
        echo "--- end diff ---"
        read -rp "Replace the existing flake file with /etc/nixos/hardware-configuration.nix? Type 'yes' to replace [default: no]: " replace_hw_config
        if [ "$replace_hw_config" = "yes" ]; then
            sudo cp -- "$hw_source" "$hw_target"
            log "Replaced hardware-configuration.nix after explicit confirmation."
        else
            HW_CONFIG_RETAINED=1
            warn "Kept the existing flake hardware-configuration.nix; verify its UUIDs and mount points before rebuild."
        fi
    elif [ ! -f "$hw_target" ]; then
        sudo cp -- "$hw_source" "$hw_target"
        log "Copied hardware-configuration.nix (machine-specific, from $NIXOS_DIR)"
    else
        log "The top-level and flake hardware-configuration.nix files are identical; no overwrite needed."
    fi
    HW_IN_PLACE=1
elif [ -f "$NIXOS_FLAKE_DIR/hardware-configuration.nix" ]; then
    # Do not trust a hardware-configuration.nix merely because it is present in
    # the cloned repository. It may contain another machine's UUIDs. Mark it as
    # unverified and keep the warning visible until the target host's generated
    # hardware configuration has been checked.
    HW_IN_PLACE=0
    warn "hardware-configuration.nix is present but may come ONLY from the repository template."
    warn "Its UUIDs likely belong to the maintainer, not to this machine."
    warn "Before rebuilding, regenerate this file for your machine with 'nixos-generate-config --show-hardware-config'."
    warn "Replace it with that output; otherwise the system may not boot."
else
    HW_IN_PLACE=0
    warn "hardware-configuration.nix was not found; a rebuild will fail (see instructions below)."
fi

# The operator may have declined replacing the existing flake hardware file.
# Re-check the exact file that will be built before installing the VFIO hook.
require_btrfs_home "$NIXOS_FLAKE_DIR/hardware-configuration.nix"

if [ -d "$REPO_DIR/nixos/hooks" ]; then
    sudo rm -rf "$NIXOS_FLAKE_DIR/hooks"
    sudo cp -r "$REPO_DIR/nixos/hooks" "$NIXOS_FLAKE_DIR/hooks"
    sudo chmod 0755 "$NIXOS_FLAKE_DIR/hooks/qemu"
    log "Copied hooks/ (configuration.nix references ./hooks/qemu as a relative path)."

    sudo sed -i \
        -e "s|^GPU_PCI=\".*\"|GPU_PCI=\"${gpu_pci}\"|" \
        -e "s|^GPU_AUDIO=\".*\"|GPU_AUDIO=\"${gpu_audio}\"|" \
        "$NIXOS_FLAKE_DIR/hooks/qemu" && log "GPU PCI addresses in the hook were updated too."

    # Do not use `git update-index --skip-worktree`: /etc/nixos is usually not a
    # Git checkout, and skip-worktree can cause confusing merge conflicts later.
else
    error "nixos/hooks/ directory not found — configuration.nix will fail to evaluate without it."
fi

# ─── VM XML PCI synchronization ──────────────────
# Keep existing VM definitions synchronized with the GPU/audio addresses written
# to hooks/qemu. Do not create a template XML for a new VM here: the manual setup
# flow classifies the XML before syncing it and needs to know no deployed XML
# existed so it can safely create a missing new-VM disk afterward.
step "VM XML PCI synchronization"
VM_XML_SYNCED=0
if [ ! -f "$REPO_DIR/vm-xml/win10.xml" ]; then
  error "vm-xml/win10.xml was not found; refusing to continue after updating the VFIO hook."
elif ! command -v python3 >/dev/null 2>&1; then
  error "python3 is unavailable; refusing to continue with hook/XML PCI addresses out of sync."
else
  # Query libvirt before deciding whether this is migration of an existing VM.
  # A query failure is not evidence that win10 is absent.
  if ! REGISTERED_DOMAINS="$(sudo virsh list --all --name)"; then
    error "Could not query libvirt while synchronizing VM XML; refusing to guess whether win10 is an existing domain."
  fi
  if grep -Fxq win10 <<< "$REGISTERED_DOMAINS" || sudo test -e "$PATCHED_XML" || sudo test -L "$PATCHED_XML"; then
    # Keep the repository XML template read-only. Update the deployed definition
    # only when libvirt already has the domain or an on-disk XML already exists.
    if sudo mkdir -p /var/lib/libvirt && sudo "$PYTHON3" "$REPO_DIR/scripts/sync-vm-xml.py" \
      "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win10.xml" "$PATCHED_XML" --domain win10; then
      VM_XML_SYNCED=1
      log "VM XML -> ${PATCHED_XML} (GPU=${gpu_pci}, Audio=${gpu_audio})"
      log "The source repository file was NOT modified."
      info "Before defining the VM, validate the ISO/source paths in the synchronized XML:"
      echo -e "     ${CYAN}sudo python3 \"${REPO_DIR}/scripts/check-vm-iso-paths.py\" \"${PATCHED_XML}\"${NC}"
      echo -e "     ${CYAN}sudo virsh define \"${PATCHED_XML}\"${NC}"
    else
      error "Could not update the VM XML; refusing to continue with hook/XML PCI addresses out of sync. Restore the backup or correct the XML, then rerun."
    fi
  else
    info "No registered win10 domain or deployed VM XML exists. Deferring fresh XML generation until VM preparation so the new-VM disk-creation branch remains reachable."
  fi
fi
if [ "$HW_IN_PLACE" = "1" ]; then
  if [ "$HW_CONFIG_RETAINED" = "1" ]; then
    warn "Preserved the existing flake hardware-configuration.nix; it differs from the parent-directory file."
    warn "Verify every partition UUID and mount setting before rebuilding."
  else
    log "hardware-configuration.nix is already in place; the manual copy step below is unnecessary."
  fi
  echo "  Verify: lsblk -f  # Are the UUIDs for all mounted partitions correct?"
else
warn "hardware-configuration.nix was NOT copied (machine-specific; UUIDs belong to this host)."
warn "The flake imports ./hardware-configuration.nix, so the file must be located here:"
echo -e "     ${CYAN}${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}"
echo ""
echo "   If the file already exists on this system:"
echo -e "     ${CYAN}sudo cp ${NIXOS_DIR}/hardware-configuration.nix ${NIXOS_FLAKE_DIR}/${NC}"
echo ""
echo "   This migration installer is for an already booted NixOS host; do not run it from the live installer."
echo "   For a fresh installation, follow INSTALLATION.md and generate hardware configuration for the mounted target."
echo "   The generated file must be installed at /mnt/etc/nixos/nixos/hardware-configuration.nix before nixos-install."
fi

# ─── Btrfs snapshot subvolume ───────────────────────────
step "Btrfs snapshot subvolume"
if findmnt -rn -o FSTYPE --target /home 2>/dev/null | grep -qi '^btrfs$'; then
  if sudo btrfs subvolume show "$SNAPSHOT_SUBVOL" >/dev/null 2>&1; then
    log "$SNAPSHOT_SUBVOL is an existing Btrfs subvolume."
  elif [ -e "$SNAPSHOT_SUBVOL" ]; then
    error "$SNAPSHOT_SUBVOL exists but is NOT a Btrfs subvolume. Move/inspect it manually; refusing to continue because neededForBoot=true requires the subvolume."
  else
    warn "$SNAPSHOT_SUBVOL is MISSING — creating the required Btrfs subvolume."
    sudo btrfs subvolume create "$SNAPSHOT_SUBVOL"
    SNAPSHOT_SUBVOL_CREATED=1
    sudo btrfs subvolume show "$SNAPSHOT_SUBVOL" >/dev/null 2>&1 \
      || error "Failed to verify $SNAPSHOT_SUBVOL as a Btrfs subvolume."
    log "Created and verified $SNAPSHOT_SUBVOL Btrfs subvolume."
  fi
else
  error "/home no longer reports a Btrfs filesystem after preflight. Refusing to continue with Home Snapper enabled; the deployment rollback will run."
fi
echo ""

# VM disk provisioning is deliberately deferred until AFTER nixos-rebuild + reboot.
# The new libvirt module provides qemu-img and creates qemu-libvirtd; using them
# before activation can stop a first-time install halfway through.
step "VM disk image (deferred until after rebuild/reboot)"
info "No VM disk or qemu-libvirtd ownership changes are made before libvirt is active."
echo ""

# ─── /nix/persist/home ──────────────────────────────────
# The old impermanence/persistent-home step was removed because this configuration
# no longer defines a home bind mount. Do not create an unused directory here.
# If a previous run left an empty directory, it is harmless; remove it manually
# only if empty: `sudo rmdir /nix/persist/home`.

# ─── Variable substitution ──────────────────────────────
step "Applying safe variable substitutions"

HOME_NIX="$NIXOS_FLAKE_DIR/home.nix"

# Fix: never interpolate user input directly into a `sed -E` replacement. Values
# containing `&` or `|` can corrupt the file or terminate the script. Python
# performs a line-based replacement, correctly escapes the Nix string, and writes
# atomically. Single quotes are valid data here; shell escaping belongs at the
# point where a value is passed to a command. Python is checked before side effects.
apply_var() {
  local var_name="$1" new_value="$2"
  if ! grep -qE "^[[:space:]]*${var_name}[[:space:]]*=" "$HOME_NIX"; then
    warn "Variable '${var_name}' not found in home.nix — skipped."
    return 0
  fi
  if ! sudo "$PYTHON3" - "$HOME_NIX" "$var_name" "$new_value" <<'PYEOF'
import re, sys, os, tempfile

path, var, value = sys.argv[1], sys.argv[2], sys.argv[3]

with open(path, encoding="utf-8") as fh:
    text = fh.read()

# Serialize for a Nix double-quoted string. A single quote is literal here;
# shell-specific quoting belongs at the shell call site, not in the stored value.
escaped = value.replace('\\', '\\\\').replace('"', '\\"').replace('${', '\\${')

pattern = re.compile(
    r'^(?P<indent>[ \t]*)' + re.escape(var) + r'[ \t]*=[ \t]*.*$', re.MULTILINE
)
new_text, n = pattern.subn(
    lambda m: '{0}{1} = "{2}";'.format(m.group("indent"), var, escaped), text
)

if n == 0:
    sys.exit(1)

directory = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(dir=directory, suffix=".applyvar.tmp")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(new_text)
    os.chmod(tmp, os.stat(path).st_mode)
    os.replace(tmp, path)
except BaseException:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
PYEOF
  then
    warn "Failed to substitute '${var_name}' — home.nix was NOT modified."
    return 1
  fi
  log "Set ${var_name}."
}

if [ "$git_name" = "changeme" ] || [ "$git_email" = "you@example.com" ]; then
  warn "Git identity is still 'changeme'/'you@example.com'; commits will"
  warn "be attributed to these placeholders. To use your own identity, edit"
  warn "the gitName / gitEmail values in home.nix."
fi
apply_var "gitName" "$git_name"
apply_var "gitEmail" "$git_email"
apply_var "monitorOutput" "$monitor_output"
apply_var "hyprlandMonitorMode" "$hypr_mon_mode"
apply_var "wallpaperVideo" "$wallpaper_video"

# ─── Final checklist ────────────────────────────────────
step "Summary"
echo ""
echo -e "  CPU:          ${CYAN}$CPU_VENDOR${NC}"
echo -e "  GPU:          ${CYAN}$GPU_VENDOR${NC}"
echo -e "  GPU PCI:      ${CYAN}${gpu_pci}${NC}  /  Audio: ${CYAN}${gpu_audio}${NC}"
echo -e "  Monitor out:  ${CYAN}${monitor_output}${NC}"
echo -e "  Hyprland mode:${CYAN} ${hypr_mon_mode}${NC}"
echo -e "  Wallpaper:    ${CYAN}${wallpaper_video}${NC}"
echo -e "  Git:          ${CYAN}${git_name} <${git_email}>${NC}"
echo ""

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  MANUAL STEPS — FOLLOW IN ORDER${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}DO NOT rebuild until disk UUIDs are correct!${NC}"
echo ""
step_num=1

echo -e "${step_num}. Update disk UUIDs in ${CYAN}${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}:"
echo "   lsblk -f   # to see UUIDs"
echo "   Then set: LUKS device, Btrfs subvolumes, EFI, swap."
((step_num++))

echo ""
echo -e "${step_num}. Ensure the hashed password file exists and is secure:"
echo "   Preserve an existing valid hash; create one only if the file is missing or empty."
echo -e "   ${CYAN}if [ ! -s /etc/nixos/hashedPassword ]; then${NC}"
echo -e "   ${CYAN}  HASH=\$(nix-shell -p whois --run 'mkpasswd --method yescrypt')${NC}"
echo -e "   ${CYAN}  printf '%s\\\\n' \"\$HASH\" | sudo tee /etc/nixos/hashedPassword >/dev/null${NC}"
echo -e "   ${CYAN}fi${NC}"
echo -e "   ${CYAN}sudo chown root:root /etc/nixos/hashedPassword${NC}"
echo -e "   ${CYAN}sudo chmod 600 /etc/nixos/hashedPassword${NC}"
echo -e "   ${CYAN}sudo test -s /etc/nixos/hashedPassword${NC}"
echo -e "   ${CYAN}password_meta=\$(sudo stat -c '%U:%G:%a' /etc/nixos/hashedPassword)${NC}"
echo -e "   ${CYAN}[ \"\$password_meta\" = 'root:root:600' ] || { echo 'hashedPassword must be root:root:600' >&2; exit 1; }${NC}"
echo -e "   ${YELLOW}(If NixOS is not active yet, nix-shell can temporarily provide whois.)${NC}"
((step_num++))

echo ""
echo -e "${step_num}. Rebuild, then REBOOT before VM disk setup:"
echo -e "   ${CYAN}sudo nixos-rebuild dry-activate --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo nixos-rebuild switch     --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo reboot${NC}"
echo -e "   ${YELLOW}Reboot, then verify IOMMU/AMD-Vi in dmesg and /sys/kernel/iommu_groups.${NC}"
((step_num++))

echo ""
echo -e "${step_num}. Verify and preflight the VM XML disk and ISO paths before preparing or starting the guest:"
if [ "$VM_XML_SYNCED" -eq 1 ]; then
  echo -e "   ${CYAN}sudo grep -E 'source file=' \"${PATCHED_XML}\"${NC}"
  echo -e "   ${CYAN}sudo python3 \"${REPO_DIR}/scripts/check-vm-iso-paths.py\" \"${PATCHED_XML}\"${NC}"
  echo -e "   ${YELLOW}The default XML expects Win10_22H2_English_x64v1.iso and virtio-win-0.1.285.iso under /var/lib/libvirt/images/.${NC}"
  echo -e "   ${YELLOW}Confirm both ISO files exist at the paths actually shown in the XML; edit custom paths deliberately.${NC}"
  echo -e "   ${YELLOW}Read the primary disk path from that same XML. For an existing VM, preserve its disk and verify it exists and is accessible to QEMU.${NC}"
  echo -e "   ${YELLOW}For a genuinely new VM only, create a missing disk at the XML's reviewed path. The default template path is /var/lib/libvirt/images/win10new.qcow2 (120G).${NC}"
  echo -e "   ${YELLOW}Do not create, chown, or chmod win10new.qcow2 unless the deployed XML actually references it and you have confirmed the file is the intended disk.${NC}"
  echo -e "   ${YELLOW}Only define the VM after the ISO/source preflight above passes and the guest is shut down.${NC}"
  echo -e "   ${CYAN}sudo virsh define \"${PATCHED_XML}\"${NC}"
  echo -e "   ${CYAN}sudo virsh list --all${NC}   ${YELLOW}→ 'win10' should appear as shut off${NC}"
  echo -e "   ${YELLOW}The installer requires exactly two PCI hostdev elements (GPU + audio).${NC}"
  echo -e "   ${YELLOW}If the deployed VM XML has extra PCI hostdevs or a nonstandard primary-disk layout, use manual migration; synchronization will stop rather than replace the XML.${NC}"
else
  echo -e "   ${YELLOW}No existing win10 domain/XML was found, so no XML was created during migration.${NC}"
  echo -e "   ${YELLOW}After reboot, use the README.md or INSTALLATION.md VM-preparation block from a persistent repository checkout.${NC}"
  echo -e "   ${YELLOW}That flow generates a fresh XML, validates ISO paths, and creates the reviewed default disk only when safe.${NC}"
fi
((step_num++))

echo ""
TRANSACTION_ACTIVE=0
trap - EXIT
log "Setup complete."
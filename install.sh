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

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.nixos-config-backup-$(date +%Y%m%d-%H%M%S)"
NIXOS_DIR="/etc/nixos"
NIXOS_FLAKE_DIR="$NIXOS_DIR/nixos"
PATCHED_XML="/var/lib/libvirt/win10.xml"

echo ""
echo -e "${CYAN}==============================================================${NC}"
echo -e "${CYAN}   NixOS Hyprland Gaming + VFIO — Safe Setup Script${NC}"
echo -e "${CYAN}==============================================================${NC}"
echo ""
info "This installer changes system files; it is not a variable-only editor."
info "It backs up existing configs, copies NixOS/Home Manager files, replaces"
info "the deployed hooks directory, and updates the libvirt VM XML."
info "It also applies GPU/audio PCI IDs and host-specific desktop values."
info "Only the five newest matching installer backups are retained; older ones may be removed."
info "Review every prompt and warning. Rebuilding the NixOS system is a separate step."
echo ""

step "Preflight checks"
if ! grep -qi nixos /etc/os-release 2>/dev/null; then
  error "This script must be run on NixOS."
fi
if [[ $EUID -eq 0 ]]; then
  error "Do not run as root. Use a normal user with sudo privileges."
fi
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

read -rp "Do you want to continue? (yes/no): " confirm
[[ "$confirm" != "yes" ]] && { info "Aborted."; exit 0; }

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

# Fix (2026-10-06): PCI addresses were not validated here. Invalid input such as
# `0000:0b:00` or `gpu` could be written into the hook and fail much later when
# the VM started. The XML synchronization code already used a regex; apply the
# same validation before writing the hook configuration.
valid_pci() {
  [[ "$1" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]$ ]]
}

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
  if valid_pci "$gpu_pci"; then break; fi
  warn "'$gpu_pci' is not a valid PCI address; expected format: 0000:0b:00.0"
  if [ "$_try" -lt 3 ]; then read -rp "GPU PCI address: " gpu_pci; fi
done
valid_pci "$gpu_pci" || error "Invalid GPU PCI address after 3 attempts; aborting installation."

for _try in 1 2 3; do
  if valid_pci "$gpu_audio"; then break; fi
  warn "'$gpu_audio' is not a valid PCI address; expected format: 0000:0b:00.1"
  if [ "$_try" -lt 3 ]; then read -rp "GPU audio PCI address: " gpu_audio; fi
done
valid_pci "$gpu_audio" || error "Invalid GPU audio PCI address after 3 attempts; aborting installation."

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
  warn "This configuration is optimized for AMD CPU + AMD GPU."
  if [[ "$CPU_VENDOR" == "intel" ]]; then
    echo "  - Switch 'hardware.cpu.amd.updateMicrocode' → 'hardware.cpu.intel.updateMicrocode'"
    echo "  - Replace 'kvm-amd' → 'kvm-intel'"
    echo "  - Also verify IOMMU in BIOS/UEFI and kernel parameters (Intel VT-d)."
    echo "  - Remove 'amd_pstate=active' kernel parameter"
  fi
  if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    echo "  - This repository does not support NVIDIA; amdgpu is the default."
    echo "  - Remove AMD_VULKAN_ICD, RADV_PERFTEST variables"
    echo "  - Switch ollama package to ollama-cuda"
  elif [[ "$GPU_VENDOR" == "intel" ]]; then
    echo "  - Remove AMD-specific env vars and amdgpu.ppfeaturemask"
    echo "  - Switch ollama to pkgs.ollama (CPU only)"
  elif [[ "$GPU_VENDOR" == "unknown" ]]; then
    warn "Selected GPU vendor could not be identified from: $gpu_pci"
  fi
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  read -rp "Press Enter to acknowledge these manual changes are needed..."
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

if [ -n "$gpu_grp" ]; then
  info "GPU ($gpu_pci) IOMMU group: $gpu_grp"
  show_iommu_group "$gpu_grp"
  if [ -n "$audio_grp" ] && [ "$audio_grp" != "$gpu_grp" ]; then
    warn "Audio function ($gpu_audio) is in a different IOMMU group: $audio_grp"
    show_iommu_group "$audio_grp"
  fi
  echo ""
  warn "If the list above contains devices other than GPU (${gpu_pci}) and audio function (${gpu_audio}),"
  warn "the GPU may not be isolated by itself unless those devices are also passed through"
  warn "(additional measures such as ACS override may be required)."
  read -rp "Continue? (type yes to continue; anything else aborts): " iommu_confirm
  [[ "$iommu_confirm" != "yes" ]] && { info "Aborted."; exit 0; }
else
  warn "Could not resolve GPU IOMMU group information (${gpu_iommu_dir}); the link may be absent or invalid."
  warn "Ensure IOMMU is enabled in firmware; skipping this check."
fi
if [ -n "$gpu_grp" ] && [ -z "$audio_grp" ]; then
  warn "Could not resolve audio-function IOMMU group information (${audio_iommu_dir}); verify isolation manually."
fi

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
read -rp "Monitor output name (for mpvpaper) [${monitor_output:-not detected}]: " input_mon
if [[ -n "${input_mon//[[:space:]]/}" ]]; then
  monitor_output="$input_mon"
fi
while [[ -z "${monitor_output//[[:space:]]/}" ]]; do
  warn "Monitor output name cannot be empty. Find the exact name with: hyprctl monitors"
  read -rp "Enter a non-empty monitor output name (e.g. DP-3): " input_mon
  if [[ -n "${input_mon//[[:space:]]/}" ]]; then
    monitor_output="$input_mon"
  fi
done

echo ""
read -rp "Hyprland monitor line (e.g. monitor = DP-3,2560x1440@170,auto,1) [monitor = ${input_mon:-$monitor_output},preferred,auto,1]: " hypr_mon_line
hypr_mon_line="${hypr_mon_line:-monitor = ${input_mon:-$monitor_output},preferred,auto,1}"

echo ""
wallpaper_video="/home/localhost/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4"
read -rp "Wallpaper video path [${wallpaper_video}]: " input_video
[[ -n "$input_video" ]] && wallpaper_video="$input_video"

echo ""
# Fix: the previous defaults exposed the maintainer's real identity. Pressing
# Enter would attribute commits to someone else. Use the same neutral placeholders
# as home.nix: changeme / you@example.com.
read -rp "Git user name [changeme]: " git_name
git_name="${git_name:-changeme}"
read -rp "Git email [you@example.com]: " git_email
git_email="${git_email:-you@example.com}"

# ─── Backup ──────────────────────────────────────────────
step "Backing up current configurations"
mkdir -p "$BACKUP_DIR"
for src in "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" \
           "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/home.nix" \
           "$NIXOS_FLAKE_DIR/flake.nix" "$NIXOS_FLAKE_DIR/flake.lock" \
           "$NIXOS_FLAKE_DIR/hooks" \
           "$NIXOS_DIR/hardware-configuration.nix" \
           "$NIXOS_FLAKE_DIR/hardware-configuration.nix"; do
    if [ -e "$src" ]; then
        # Fix: writing every backup directly into `$BACKUP_DIR/` caused filename
        # collisions when two source paths had the same basename. Flatten each
        # full source path by replacing `/` with `_`, so every backup is unique.
        backup_name="$(echo "$src" | tr '/' '_')"
        if cp -rL "$src" "$BACKUP_DIR/$backup_name" 2>/dev/null; then
            log "Backed up: $backup_name"
        else
            warn "Backup FAILED for: $src"
            warn "No existing configuration has been replaced yet; aborting for safety."
            exit 1
        fi
    fi
done
log "Backup saved to $BACKUP_DIR"

# Keep the five newest installer backups. A matching prefix is not enough:
# only directories created with this script's exact timestamp format qualify.
# Filter BEFORE sorting so unrelated lookalike directories cannot displace a real
# backup from the five-entry retention window. NUL delimiters preserve spaces.
backup_count=0
while IFS=$'\t' read -r -d '' _backup_mtime old_backup; do
    ((backup_count += 1))
    [ "$old_backup" = "$BACKUP_DIR" ] && continue
    if (( backup_count > 5 )); then
        rm -rf -- "$old_backup"
        log "Removed old installer backup: $old_backup"
    fi
done < <(
    while IFS= read -r -d '' candidate; do
        backup_name="${candidate##*/}"
        [[ "$backup_name" =~ ^\.nixos-config-backup-[0-9]{8}-[0-9]{6}$ ]] || continue
        backup_mtime="$(stat -c '%Y' -- "$candidate" 2>/dev/null)" || continue
        printf '%s\t%s\0' "$backup_mtime" "$candidate"
    done < <(find "$HOME" -mindepth 1 -maxdepth 1 -type d \
              -name '.nixos-config-backup-*' -print0) \
    | sort -z -t $'\t' -k1,1nr
)

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
    raise SystemExit(1)
pattern = re.compile(
    r"^\s*" + re.escape(setting) +
    r'\s*=\s*(?:lib\.mkDefault\s*)?"(\d{2}\.\d{2})"\s*;',
    re.MULTILINE,
)
match = pattern.search(content)
if not match:
    raise SystemExit(1)
print(match.group(1))
PY_STATE_VERSION
}

read_state_version() {
  local setting="$1" candidate value="" found_file=0
  shift
  for candidate in "$@"; do
    [ -f "$candidate" ] || continue
    found_file=1
    if value="$(extract_state_version "$candidate" "$setting")"; then
      STATE_VERSION_VALUE="$value"
      STATE_VERSION_SOURCE="$candidate"
      return 0
    fi
  done

  if [ "$found_file" -eq 1 ]; then
    warn "${setting} was not found as a simple literal in existing files. Refusing to guess for safety."
    read -rp "Enter the existing ${setting} value (e.g. 24.11; leave blank to cancel if unknown): " value
    [[ "$value" =~ ^[0-9]{2}\.[0-9]{2}$ ]] || error "${setting} could not be validated; installation stopped before files were changed."
    STATE_VERSION_VALUE="$value"
    STATE_VERSION_SOURCE="user input"
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
read_state_version "home.stateVersion" "$NIXOS_FLAKE_DIR/home.nix" "$NIXOS_DIR/home.nix" "$HOME/.config/home-manager/home.nix"
HOME_STATE_VERSION="$STATE_VERSION_VALUE"
log "home.stateVersion source: $STATE_VERSION_SOURCE${HOME_STATE_VERSION:+ (value $HOME_STATE_VERSION)}"

sudo mkdir -p "$NIXOS_FLAKE_DIR"
for f in configuration.nix home.nix flake.nix flake.lock; do
    if [ -f "$REPO_DIR/nixos/$f" ]; then
        sudo cp "$REPO_DIR/nixos/$f" "$NIXOS_FLAKE_DIR/$f"
        log "Copied $f"
    else
        warn "Skipping missing file: $f"
    fi
done

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
# Keep the PCI addresses in the deployed VM XML synchronized with the GPU and
# audio addresses written to hooks/qemu. Otherwise the hook could bind the new
# devices while libvirt still tried to open the old PCI addresses.
step "VM XML PCI synchronization"
if [ ! -f "$REPO_DIR/vm-xml/win10.xml" ]; then
  error "vm-xml/win10.xml was not found; refusing to continue after updating the VFIO hook."
elif ! command -v python3 >/dev/null 2>&1; then
  error "python3 is unavailable; refusing to continue with hook/XML PCI addresses out of sync."
else
  # Keep the repository XML template read-only. Write the synchronized copy to
  # libvirt's directory instead of modifying the source tree or setting
  # skip-worktree, which can hide changes and cause later merge conflicts.
  # Run the XML update as root: the destination is owned by the system.
  if sudo mkdir -p /var/lib/libvirt && sudo "$PYTHON3" - "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win10.xml" "$PATCHED_XML" <<'PYEOF'
import os, re, shutil, sys, time, uuid as uuidlib, secrets, tempfile, stat

gpu, aud, src, dst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def xml_attrs(addr):
    m = re.match(r'^([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$', addr)
    if not m:
        sys.exit(f"invalid PCI address: {addr}")
    d, b, s, f = m.groups()
    return f'domain="0x{d}" bus="0x{b}" slot="0x{s}" function="0x{f}"'

data = open(src, encoding="utf-8").read()

# Give a new deployment a unique libvirt UUID and locally administered MAC.
# If a destination XML already exists, preserve its identity on reruns so DHCP
# reservations and Windows device identity do not change on every install.
template_uuid = re.search(r'<uuid>([^<]+)</uuid>', data)
template_mac = re.search(r'<mac\s+address="([^"]+)"\s*/>', data)
if not template_uuid or not template_mac:
    sys.exit("ERROR: no UUID or MAC address found in the XML template; no file was written.")

old_data = ""
if os.path.exists(dst):
    with open(dst, encoding="utf-8") as old_file:
        old_data = old_file.read()
old_uuid = re.search(r'<uuid>([^<]+)</uuid>', old_data)
old_mac = re.search(r'<mac\s+address="([^"]+)"\s*/>', old_data)

vm_uuid = old_uuid.group(1) if old_uuid else str(uuidlib.uuid4())
vm_mac = old_mac.group(1) if old_mac else "52:54:00:" + ":".join(secrets.token_hex(3)[i:i+2] for i in (0, 2, 4))
data = re.sub(r'<uuid>[^<]+</uuid>', f'<uuid>{vm_uuid}</uuid>', data, count=1)
data = re.sub(r'<mac\s+address="[^"]+"\s*/>', f'<mac address="{vm_mac}"/>', data, count=1)

pattern = re.compile(
    r"(<hostdev\b(?=[^>]*\btype\s*=\s*['\"]pci['\"])[^>]*>\s*"
    r"(?:<driver\b[^>]*/>\s*)?<source>\s*<address\s+)([^/]+)(/>)",
    re.DOTALL)

addrs = [xml_attrs(gpu), xml_attrs(aud)]
counter = [0]

def repl(m):
    i = counter[0]
    counter[0] += 1
    return m.group(1) + (addrs[i] if i < len(addrs) else m.group(2)) + m.group(3)

new = pattern.sub(repl, data)

# Only PCI hostdev addresses are synchronized; USB hostdevs must remain untouched.
n = counter[0]
if n == 0:
    sys.exit("ERROR: no PCI hostdev elements found in XML (0 matches). No file was written.")
if n != 2:
    print(f"WARNING: found {n} PCI hostdev elements in XML; expected exactly 2.", file=sys.stderr)
    if n < 2:
        print("WARNING: the GPU/audio PCI pair may be incomplete; verify both entries manually.", file=sys.stderr)
    else:
        print(f"WARNING: {n-2} extra PCI hostdev element(s) were not synchronized; review them manually.",
              file=sys.stderr)
    print("WARNING: verify PCI addresses with the command below:", file=sys.stderr)
    print(f"  grep -n -A6 'hostdev.*type=\"pci\"' {dst}", file=sys.stderr)

if os.path.exists(dst):
    backup = f"{dst}.bak-{int(time.time())}"
    shutil.copy2(dst, backup)
    print(f"NOTE: existing XML backed up to -> {backup}")
    previous_stat = os.stat(dst)
    target_mode = stat.S_IMODE(previous_stat.st_mode)
else:
    previous_stat = None
    # Match the usual mode of a newly-created text file under umask 022.
    target_mode = 0o644

# Write to a temporary file in the destination directory and atomically replace
# the destination. A failed write leaves the previous XML untouched.
target_dir = os.path.dirname(dst) or "."
tmp_path = None
try:
    fd, tmp_path = tempfile.mkstemp(
        dir=target_dir,
        prefix=f".{os.path.basename(dst)}.",
        suffix=".tmp",
    )
    with os.fdopen(fd, "w", encoding="utf-8") as tmp_file:
        tmp_file.write(new)
        tmp_file.flush()
        os.fsync(tmp_file.fileno())
    os.chmod(tmp_path, target_mode)
    if previous_stat is not None:
        os.chown(tmp_path, previous_stat.st_uid, previous_stat.st_gid)
    os.replace(tmp_path, dst)
    tmp_path = None
    # Best-effort directory sync makes the rename durable across a sudden crash.
    try:
        dir_fd = os.open(target_dir, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    except OSError:
        pass
except BaseException:
    if tmp_path is not None:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
    raise

print(f"OK: found {n} PCI hostdev elements; synchronized {min(n, 2)} -> {dst}")
PYEOF
  then
    log "vm-xml/win10.xml -> ${PATCHED_XML} (GPU=${gpu_pci}, Audio=${gpu_audio})"
    log "The source repository file was NOT modified."
    echo -e "     ${CYAN}sudo virsh define ${PATCHED_XML}${NC}"
  else
    error "Could not update the VM XML; refusing to continue with hook/XML PCI addresses out of sync. Restore the backup or correct the XML, then rerun."
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
echo "   For a fresh installation:"
echo -e "     ${CYAN}sudo cp /mnt/etc/nixos/hardware-configuration.nix ${NIXOS_FLAKE_DIR}/${NC}"
echo ""
echo "   Or create it manually:"
echo -e "     ${CYAN}sudo nixos-generate-config --root /mnt${NC}"
echo -e "     ${CYAN}lsblk -f${NC}  # Verify the UUIDs"
fi

# ─── Btrfs snapshot subvolume ───────────────────────────
step "Btrfs snapshot subvolume"
if findmnt -no FSTYPE /home 2>/dev/null | grep -qi btrfs; then
  if sudo btrfs subvolume show /home/.snapshots >/dev/null 2>&1; then
    log "/home/.snapshots is an existing Btrfs subvolume."
  elif [ -e /home/.snapshots ]; then
    error "/home/.snapshots exists but is NOT a Btrfs subvolume. Move/inspect it manually; refusing to continue because neededForBoot=true requires the subvolume."
  else
    warn "/home/.snapshots is MISSING — creating the required Btrfs subvolume."
    sudo btrfs subvolume create /home/.snapshots
    sudo btrfs subvolume show /home/.snapshots >/dev/null 2>&1 \
      || error "Failed to verify /home/.snapshots as a Btrfs subvolume."
    log "Created and verified /home/.snapshots Btrfs subvolume."
  fi
else
  warn "/home is not a btrfs mount — skipping (snapper home config will not work)."
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
apply_var "hyprlandMonitorLine" "$hypr_mon_line"
apply_var "wallpaperVideo" "$wallpaper_video"

# ─── Final checklist ────────────────────────────────────
step "Summary"
echo ""
echo -e "  CPU:          ${CYAN}$CPU_VENDOR${NC}"
echo -e "  GPU:          ${CYAN}$GPU_VENDOR${NC}"
echo -e "  GPU PCI:      ${CYAN}${gpu_pci}${NC}  /  Audio: ${CYAN}${gpu_audio}${NC}"
echo -e "  Monitor out:  ${CYAN}${monitor_output}${NC}"
echo -e "  Hyprland:     ${CYAN}${hypr_mon_line}${NC}"
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

if [[ "$CPU_VENDOR" != "amd" || "$GPU_VENDOR" != "amd" ]]; then
  echo ""
  echo -e "${step_num}. Apply hardware-specific changes as shown earlier."
  ((step_num++))
fi

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
echo -e "${step_num}. After reboot, prepare the VM disk and register the VM:"
echo -e "   ${CYAN}sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu${NC}"
echo -e "   ${CYAN}if [ ! -f /var/lib/libvirt/images/win10new.qcow2 ]; then sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G; fi${NC}"
echo -e "   ${CYAN}sudo chown qemu-libvirtd:qemu-libvirtd /var/lib/libvirt/images/win10new.qcow2${NC}"
echo -e "   ${CYAN}sudo chmod 0660 /var/lib/libvirt/images/win10new.qcow2${NC}"
echo -e "   ${YELLOW}Copy the ISO files into /var/lib/libvirt/images/:${NC}"
echo -e "   ${YELLOW}Win10_22H2_English_x64v1.iso and virtio-win-0.1.285.iso${NC}"
echo -e "   ${CYAN}sudo virsh define /var/lib/libvirt/win10.xml${NC}"
echo -e "   ${CYAN}sudo virsh list --all${NC}   ${YELLOW}→ 'win10' should appear as shut off${NC}"
echo -e "   ${YELLOW}If there are 3+ PCI hostdev elements, review the warning and edit extras manually.${NC}"
((step_num++))

echo ""
log "Setup complete."

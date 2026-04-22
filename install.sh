#!/usr/bin/env bash

# =============================================================================
# NixOS Hyprland Gaming + VFIO Config — Experimental Installer
# =============================================================================
# ⚠️  EXPERIMENTAL: Manual file copying is strongly recommended.
#     Review all config files before running this script.
# =============================================================================

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
NIXOS_DIR="/etc/nixos"

log()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()  { echo -e "\n${BOLD}${CYAN}▶ $1${NC}"; }

echo ""
echo -e "${CYAN}=================================================================${NC}"
echo -e "${CYAN}   NixOS Hyprland Gaming + VFIO Config — Experimental Installer ${NC}"
echo -e "${CYAN}=================================================================${NC}"
echo ""
warn "This installer is EXPERIMENTAL."
warn "Manual file copying is strongly recommended."
warn "Always review config files before applying!"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  VFIO WARNING:${NC}"
echo -e "${RED}  If you have a single GPU setup, running this config may       ${NC}"
echo -e "${RED}  cause display loss when starting the VM.                      ${NC}"
echo -e "${RED}  GPU PCI addresses in configuration.nix MUST be updated        ${NC}"
echo -e "${RED}  to match your system before rebuilding!                       ${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================
step "Preflight checks"

if grep -qi nixos /etc/os-release 2>/dev/null; then
  log "Verified: running on NixOS."
else
  error "This is not NixOS. Aborting."
fi

if ! command -v lspci &>/dev/null; then
  error "pciutils not found. Run: nix-shell -p pciutils"
fi

read -rp "Do you want to continue? (yes/no): " CONFIRM </dev/tty
[[ "$CONFIRM" != "yes" ]] && { info "Aborted."; exit 0; }

# =============================================================================
# STEP 1 — Detect CPU
# =============================================================================
step "Step 1 — Detecting CPU"

CPU_VENDOR=""
if grep -qi "GenuineIntel" /proc/cpuinfo; then
  CPU_VENDOR="intel"
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
  CPU_VENDOR="amd"
else
  CPU_VENDOR="unknown"
fi

log "CPU vendor detected: $CPU_VENDOR"

if [[ "$CPU_VENDOR" == "intel" ]]; then
  echo ""
  warn "Intel CPU detected. The following changes are required in configuration.nix:"
  echo -e "  ${CYAN}hardware.cpu.amd.updateMicrocode${NC}  →  ${CYAN}hardware.cpu.intel.updateMicrocode${NC}"
  echo -e "  ${CYAN}boot.kernelModules = [ \"kvm-amd\" ]${NC}  →  ${CYAN}[ \"kvm-intel\" ]${NC}"
  echo -e "  ${CYAN}\"amd_pstate=active\"${NC}  →  remove or replace with  ${CYAN}\"intel_pstate=active\"${NC}"
  echo -e "  ${CYAN}\"amdgpu.ppfeaturemask=0xffffffff\"${NC}  →  remove (AMD-only)"
  echo -e "  ${CYAN}\"amd_iommu=on\"${NC}  →  ${CYAN}\"intel_iommu=on\"${NC}"
  echo ""
  read -rp "Automatically patch configuration.nix for Intel CPU? (yes/no): " PATCH_CPU </dev/tty
  PATCH_CPU_INTEL=false
  [[ "$PATCH_CPU" == "yes" ]] && PATCH_CPU_INTEL=true
elif [[ "$CPU_VENDOR" == "amd" ]]; then
  log "AMD CPU confirmed — no CPU-related changes needed."
  PATCH_CPU_INTEL=false
else
  warn "Unknown CPU vendor. Please review configuration.nix manually."
  PATCH_CPU_INTEL=false
fi

# =============================================================================
# STEP 2 — Detect GPU
# =============================================================================
step "Step 2 — Detecting GPU"

GPU_LINE=$(lspci | grep -i vga | head -1)
GPU_VENDOR=""
if echo "$GPU_LINE" | grep -qi "AMD\|ATI\|Radeon"; then
  GPU_VENDOR="amd"
elif echo "$GPU_LINE" | grep -qi "NVIDIA\|GeForce"; then
  GPU_VENDOR="nvidia"
elif echo "$GPU_LINE" | grep -qi "Intel"; then
  GPU_VENDOR="intel"
else
  GPU_VENDOR="unknown"
fi

log "GPU vendor detected: $GPU_VENDOR"
echo -e "  ${CYAN}$GPU_LINE${NC}"
echo ""

PATCH_GPU=false
if [[ "$GPU_VENDOR" == "nvidia" ]]; then
  warn "NVIDIA GPU detected. Required changes in configuration.nix:"
  echo -e "  ${CYAN}services.xserver.videoDrivers = [ \"amdgpu\" ]${NC}  →  ${CYAN}[ \"nvidia\" ]${NC}"
  echo -e "  Add: ${CYAN}hardware.nvidia.modesetting.enable = true;${NC}"
  echo -e "  Add: ${CYAN}hardware.nvidia.open = false;${NC}"
  echo -e "  Remove: ${CYAN}AMD_VULKAN_ICD, RADV_PERFTEST${NC} environment variables"
  echo -e "  Ollama: ${CYAN}pkgs.ollama-rocm${NC}  →  ${CYAN}pkgs.ollama-cuda${NC}"
  echo ""
  read -rp "Automatically patch configuration.nix for NVIDIA GPU? (yes/no): " PATCH_GPU_ANS </dev/tty
  [[ "$PATCH_GPU_ANS" == "yes" ]] && PATCH_GPU=true
elif [[ "$GPU_VENDOR" == "intel" ]]; then
  warn "Intel integrated GPU detected. Required changes:"
  echo -e "  ${CYAN}services.xserver.videoDrivers = [ \"amdgpu\" ]${NC}  →  ${CYAN}[ \"modesetting\" ]${NC}"
  echo -e "  Remove: ${CYAN}AMD_VULKAN_ICD, RADV_PERFTEST, amdgpu.ppfeaturemask${NC}"
  echo -e "  Ollama: ${CYAN}pkgs.ollama-rocm${NC}  →  ${CYAN}pkgs.ollama${NC}  (CPU mode)"
  echo ""
  read -rp "Automatically patch configuration.nix for Intel GPU? (yes/no): " PATCH_GPU_ANS </dev/tty
  [[ "$PATCH_GPU_ANS" == "yes" ]] && PATCH_GPU=true
elif [[ "$GPU_VENDOR" == "amd" ]]; then
  log "AMD GPU confirmed — no GPU driver changes needed."
else
  warn "Unknown GPU. Please review configuration.nix manually."
fi

# =============================================================================
# STEP 3 — Detect GPU PCI addresses for VFIO
# =============================================================================
step "Step 3 — GPU PCI addresses for VFIO passthrough"

echo -e "${YELLOW}  VGA / GPU devices found on your system:${NC}"
lspci -nn | grep -iE "vga|3d|display" | sed 's/^/    /'
echo ""
echo -e "${YELLOW}  Audio devices found on your system:${NC}"
lspci -nn | grep -i audio | sed 's/^/    /'
echo ""

warn "Example format: 0000:0b:00.0"
echo ""
read -rp "Enter your GPU VGA PCI address (leave blank to skip VFIO patching): " GPU_PCI_NEW </dev/tty
read -rp "Enter your GPU Audio PCI address (leave blank to skip):              " GPU_AUDIO_NEW </dev/tty

# Also detect vendor:device IDs for vfio-pci new_id lines
VFIO_GPU_ID=""
VFIO_AUDIO_ID=""
if [[ -n "$GPU_PCI_NEW" ]]; then
  RAW_ID=$(lspci -nn | grep "^${GPU_PCI_NEW#0000:}" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | head -1)
  if [[ -n "$RAW_ID" ]]; then
    VFIO_GPU_ID=$(echo "$RAW_ID" | tr ':' ' ')
    log "Detected GPU vendor:device ID for vfio-pci: $VFIO_GPU_ID"
  else
    warn "Could not auto-detect GPU vendor:device ID. You will need to update it manually."
  fi
fi
if [[ -n "$GPU_AUDIO_NEW" ]]; then
  RAW_ID=$(lspci -nn | grep "^${GPU_AUDIO_NEW#0000:}" | grep -oP '\[\K[0-9a-f]{4}:[0-9a-f]{4}(?=\])' | head -1)
  if [[ -n "$RAW_ID" ]]; then
    VFIO_AUDIO_ID=$(echo "$RAW_ID" | tr ':' ' ')
    log "Detected audio vendor:device ID for vfio-pci: $VFIO_AUDIO_ID"
  else
    warn "Could not auto-detect audio vendor:device ID. You will need to update it manually."
  fi
fi

# =============================================================================
# STEP 4 — Detect monitor resolution
# =============================================================================
step "Step 4 — Monitor resolution"

DETECTED_RES=""
if command -v wlr-randr &>/dev/null; then
  DETECTED_RES=$(wlr-randr 2>/dev/null | grep -oP '\d+x\d+@\d+\.\d+' | head -1 | sed 's/@[^@]*$//')
  HZ=$(wlr-randr 2>/dev/null | grep -oP '\d+x\d+@\K\d+' | head -1)
elif command -v xrandr &>/dev/null; then
  DETECTED_RES=$(xrandr 2>/dev/null | grep '\*' | awk '{print $1}' | head -1)
  HZ=$(xrandr 2>/dev/null | grep '\*' | grep -oP '[\d.]+\*' | tr -d '*' | cut -d. -f1 | head -1)
fi

CURRENT_MON="monitor = ,2560x1440@170,auto,1"
if [[ -n "$DETECTED_RES" && -n "$HZ" ]]; then
  log "Detected resolution: ${DETECTED_RES}@${HZ}Hz"
  echo ""
  read -rp "Use detected resolution ${DETECTED_RES}@${HZ} in hyprland.conf? (yes/no): " USE_RES </dev/tty
  if [[ "$USE_RES" == "yes" ]]; then
    NEW_MON_LINE="monitor = ,${DETECTED_RES}@${HZ},auto,1"
  else
    read -rp "Enter resolution manually (e.g. 1920x1080@144, leave blank to keep 2560x1440@170): " MANUAL_RES </dev/tty
    NEW_MON_LINE="monitor = ,${MANUAL_RES:-2560x1440@170},auto,1"
  fi
else
  warn "Could not auto-detect resolution (no active Wayland/X session)."
  read -rp "Enter resolution manually (e.g. 1920x1080@144, leave blank to keep 2560x1440@170): " MANUAL_RES </dev/tty
  NEW_MON_LINE="monitor = ,${MANUAL_RES:-2560x1440@170},auto,1"
fi

# =============================================================================
# STEP 5 — Git user info
# =============================================================================
step "Step 5 — Git user info for home.nix"

CURRENT_GIT_NAME="Umpug"
CURRENT_GIT_EMAIL="141457520+kUmutUK@users.noreply.github.com"

echo -e "  Current values in home.nix:"
echo -e "    userName  = ${CYAN}\"$CURRENT_GIT_NAME\"${NC}"
echo -e "    userEmail = ${CYAN}\"$CURRENT_GIT_EMAIL\"${NC}"
echo ""
read -rp "Enter your git username  (leave blank to keep current): " GIT_NAME </dev/tty
read -rp "Enter your git email     (leave blank to keep current): " GIT_EMAIL </dev/tty
GIT_NAME="${GIT_NAME:-$CURRENT_GIT_NAME}"
GIT_EMAIL="${GIT_EMAIL:-$CURRENT_GIT_EMAIL}"
log "Git info will be set to: $GIT_NAME <$GIT_EMAIL>"

# =============================================================================
# STEP 6 — Backup existing configs
# =============================================================================
step "Step 6 — Backing up existing configs"

info "Backup destination: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup() {
  local src=$1
  if [ -e "$src" ]; then
    cp -rL "$src" "$BACKUP_DIR/" && log "Backed up: $src"
  fi
}

backup "$HOME/.config/hypr"
backup "$HOME/.config/waybar"
backup "$HOME/.config/gtk-3.0"
backup "$HOME/.config/gtk-4.0"
backup "$NIXOS_DIR/configuration.nix"
backup "$NIXOS_DIR/home.nix"
backup "$NIXOS_DIR/flake.nix"
backup "$NIXOS_DIR/hardware-configuration.nix"

log "Backup complete → $BACKUP_DIR"

# =============================================================================
# STEP 7 — Copy NixOS config files
# =============================================================================
step "Step 7 — Copying NixOS config files"

[ ! -d "$REPO_DIR/nixos" ] && error "nixos/ directory not found in repo."

for f in configuration.nix home.nix flake.nix flake.lock; do
  if [ -f "$REPO_DIR/nixos/$f" ]; then
    sudo cp "$REPO_DIR/nixos/$f" "$NIXOS_DIR/$f" && log "Copied: $f"
  else
    warn "Not found, skipping: $f"
  fi
done

warn "hardware-configuration.nix was NOT copied — it is machine-specific."
warn "Your existing hardware-configuration.nix has been kept intact."

# =============================================================================
# STEP 8 — Copy user config files
# =============================================================================
step "Step 8 — Copying user config files"

mkdir -p "$HOME/.config"

copy_config() {
  local src="$REPO_DIR/$1"
  local dst="$HOME/.config/$1"
  if [ -d "$src" ]; then
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      rm -rf "$dst" && log "Removed existing (was Home Manager symlink): $dst"
    fi
    cp -r "$src" "$HOME/.config/" && log "Copied: $1 → $dst"
  else
    warn "Directory not found, skipping: $src"
  fi
}

copy_config "hypr"
copy_config "waybar"
copy_config "gtk-3.0"
copy_config "gtk-4.0"

# =============================================================================
# STEP 9 — Apply all patches to copied config files
# =============================================================================
step "Step 9 — Applying patches"

CONF="$NIXOS_DIR/configuration.nix"
HOME_NIX="$NIXOS_DIR/home.nix"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

# --- Git info patch ---
if [[ "$GIT_NAME" != "$CURRENT_GIT_NAME" ]] || [[ "$GIT_EMAIL" != "$CURRENT_GIT_EMAIL" ]]; then
  sudo sed -i \
    -e "s|userName  = \"$CURRENT_GIT_NAME\"|userName  = \"$GIT_NAME\"|g" \
    -e "s|userEmail = \"$CURRENT_GIT_EMAIL\"|userEmail = \"$GIT_EMAIL\"|g" \
    "$HOME_NIX" && log "Patched git info in home.nix"
fi

# --- Monitor resolution patch ---
if [[ "$NEW_MON_LINE" != "$CURRENT_MON" ]]; then
  sed -i "s|$CURRENT_MON|$NEW_MON_LINE|g" "$HYPR_CONF" \
    && log "Patched monitor resolution in hyprland.conf: $NEW_MON_LINE"
fi

# --- GPU PCI address patch ---
if [[ -n "$GPU_PCI_NEW" ]]; then
  sudo sed -i "s|GPU_PCI=\"0000:0b:00.0\"|GPU_PCI=\"$GPU_PCI_NEW\"|g" "$CONF" \
    && log "Patched GPU_PCI → $GPU_PCI_NEW"
fi
if [[ -n "$GPU_AUDIO_NEW" ]]; then
  sudo sed -i "s|GPU_AUDIO=\"0000:0b:00.1\"|GPU_AUDIO=\"$GPU_AUDIO_NEW\"|g" "$CONF" \
    && log "Patched GPU_AUDIO → $GPU_AUDIO_NEW"
fi

# --- VFIO vendor:device ID patch ---
if [[ -n "$VFIO_GPU_ID" ]]; then
  sudo sed -i "s|echo \"1002 73df\" > \"\$GPU_VFIO_PATH/new_id\"|echo \"$VFIO_GPU_ID\" > \"\$GPU_VFIO_PATH/new_id\"|g" "$CONF" \
    && log "Patched vfio-pci GPU new_id → $VFIO_GPU_ID"
fi
if [[ -n "$VFIO_AUDIO_ID" ]]; then
  sudo sed -i "s|echo \"1002 ab28\" > \"\$GPU_VFIO_PATH/new_id\"|echo \"$VFIO_AUDIO_ID\" > \"\$GPU_VFIO_PATH/new_id\"|g" "$CONF" \
    && log "Patched vfio-pci audio new_id → $VFIO_AUDIO_ID"
fi

# --- Intel CPU patches ---
if [[ "$PATCH_CPU_INTEL" == true ]]; then
  sudo sed -i \
    -e 's|hardware\.cpu\.amd\.updateMicrocode|hardware.cpu.intel.updateMicrocode|g' \
    -e 's|"kvm-amd"|"kvm-intel"|g' \
    -e 's|"amd_pstate=active"||g' \
    -e 's|"amd_iommu=on"|"intel_iommu=on"|g' \
    -e 's|"amdgpu\.ppfeaturemask=0xffffffff"||g' \
    "$CONF" && log "Patched configuration.nix for Intel CPU"
  warn "Empty lines may remain where AMD params were removed — review manually."
fi

# --- NVIDIA GPU patches ---
if [[ "$PATCH_GPU" == true && "$GPU_VENDOR" == "nvidia" ]]; then
  sudo sed -i \
    -e 's|services\.xserver\.videoDrivers = \[ "amdgpu" \]|services.xserver.videoDrivers = [ "nvidia" ]|g' \
    -e 's|AMD_VULKAN_ICD = "RADV";||g' \
    -e 's|RADV_PERFTEST  = "gpl,nggc";||g' \
    -e 's|package = pkgs\.ollama-rocm|package = pkgs.ollama-cuda|g' \
    "$CONF" && log "Patched configuration.nix for NVIDIA GPU"
  warn "Manually add 'hardware.nvidia.modesetting.enable = true;' to configuration.nix."
  warn "Remove any remaining amdgpu kernel parameters."
fi

# --- Intel GPU patches ---
if [[ "$PATCH_GPU" == true && "$GPU_VENDOR" == "intel" ]]; then
  sudo sed -i \
    -e 's|services\.xserver\.videoDrivers = \[ "amdgpu" \]|services.xserver.videoDrivers = [ "modesetting" ]|g' \
    -e 's|AMD_VULKAN_ICD = "RADV";||g' \
    -e 's|RADV_PERFTEST  = "gpl,nggc";||g' \
    -e 's|"amdgpu\.ppfeaturemask=0xffffffff"||g' \
    -e 's|package = pkgs\.ollama-rocm|package = pkgs.ollama|g' \
    "$CONF" && log "Patched configuration.nix for Intel GPU"
fi

# =============================================================================
# STEP 10 — Final summary
# =============================================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  PATCHES APPLIED SUMMARY${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  CPU:          ${CYAN}$CPU_VENDOR${NC}  (Intel patches: $PATCH_CPU_INTEL)"
echo -e "  GPU:          ${CYAN}$GPU_VENDOR${NC}  (GPU patches: $PATCH_GPU)"
echo -e "  GPU PCI:      ${CYAN}${GPU_PCI_NEW:-not changed}${NC}"
echo -e "  GPU Audio:    ${CYAN}${GPU_AUDIO_NEW:-not changed}${NC}"
echo -e "  VFIO GPU ID:  ${CYAN}${VFIO_GPU_ID:-not detected}${NC}"
echo -e "  VFIO Audio ID:${CYAN}${VFIO_AUDIO_ID:-not detected}${NC}"
echo -e "  Monitor:      ${CYAN}$NEW_MON_LINE${NC}"
echo -e "  Git name:     ${CYAN}$GIT_NAME${NC}"
echo -e "  Git email:    ${CYAN}$GIT_EMAIL${NC}"
echo -e "  Backup:       ${CYAN}$BACKUP_DIR${NC}"
echo ""

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  STILL REQUIRED MANUALLY:${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
MANUAL_STEP=1

echo -e "  ${MANUAL_STEP}. Update disk UUIDs in ${CYAN}/etc/nixos/hardware-configuration.nix${NC}:"
echo -e "       cryptsetup luksUUID /dev/nvme0n1p3   → LUKS UUID"
echo -e "       blkid /dev/mapper/cryptroot           → Btrfs UUID"
echo -e "       blkid /dev/nvme0n1p1                  → EFI UUID"
echo -e "       blkid /dev/nvme0n1p2                  → Swap UUID"
echo ""
MANUAL_STEP=$((MANUAL_STEP + 1))

if [[ "$GPU_VENDOR" == "nvidia" && "$PATCH_GPU" == true ]]; then
  echo -e "  ${MANUAL_STEP}. Add NVIDIA-specific options to ${CYAN}/etc/nixos/configuration.nix${NC}:"
  echo -e "       hardware.nvidia.modesetting.enable = true;"
  echo -e "       hardware.nvidia.open = false;"
  echo ""
  MANUAL_STEP=$((MANUAL_STEP + 1))
fi

echo -e "  ${MANUAL_STEP}. Add your SSH public key (password auth is disabled):"
echo -e "${CYAN}       ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos${NC}"
echo ""
MANUAL_STEP=$((MANUAL_STEP + 1))

echo -e "  ${MANUAL_STEP}. When everything looks correct, rebuild:"
echo -e "${CYAN}       sudo nixos-rebuild switch --flake /etc/nixos#nixos${NC}"
echo ""
echo -e "${RED}  DO NOT rebuild until disk UUIDs are correct in               ${NC}"
echo -e "${RED}  hardware-configuration.nix. Wrong UUIDs = unbootable system. ${NC}"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
log "Done. Review the changes above, then run nixos-rebuild when ready."
echo ""

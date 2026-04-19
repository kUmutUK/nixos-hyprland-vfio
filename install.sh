#!/usr/bin/env bash

# =============================================================================
# NixOS Hyprland Gaming + VFIO Config — Experimental Installer
# =============================================================================
# ⚠️  EXPERIMENTAL: Manual file copying is strongly recommended.
#     Review all config files before running this script.
#     This script does NOT auto-apply GPU PCI addresses.
# =============================================================================

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
NIXOS_DIR="/etc/nixos"

log()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
info()   { echo -e "${CYAN}[INFO]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

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

read -rp "Do you want to continue? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { info "Aborted."; exit 0; }

# =============================================================================
# STEP 1 — Detect GPU PCI addresses
# =============================================================================
echo ""
info "Detecting GPU PCI addresses..."
echo ""
echo -e "${YELLOW}  VGA / GPU devices found on your system:${NC}"
lspci | grep -i vga | sed 's/^/    /'
echo ""
echo -e "${YELLOW}  Audio devices found on your system:${NC}"
lspci | grep -i audio | sed 's/^/    /'
echo ""
warn "GPU PCI addresses are NOT automatically applied."
warn "After installation, manually update these values in /etc/nixos/configuration.nix:"
echo ""
echo -e "${CYAN}    GPU_PCI=\"0000:XX:XX.X\"   ← your GPU VGA address${NC}"
echo -e "${CYAN}    GPU_AUDIO=\"0000:XX:XX.X\" ← your GPU audio address${NC}"
echo ""
read -rp "Press ENTER to continue..."

# =============================================================================
# STEP 2 — Backup existing configs
# =============================================================================
echo ""
info "Backing up existing configs to: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup() {
  local src=$1
  if [ -e "$src" ]; then
    cp -r "$src" "$BACKUP_DIR/" && log "Backed up: $src"
  fi
}

backup "$HOME/.config/hypr"
backup "$HOME/.config/waybar"
backup "$HOME/.config/gtk-3.0"
backup "$HOME/.config/gtk-4.0"
backup "$NIXOS_DIR/configuration.nix"
backup "$NIXOS_DIR/home.nix"
backup "$NIXOS_DIR/flake.nix"

log "Backup complete → $BACKUP_DIR"

# =============================================================================
# STEP 3 — Copy NixOS config files
# =============================================================================
echo ""
info "Copying NixOS config files to $NIXOS_DIR ..."

[ ! -d "$REPO_DIR/nixos" ] && error "nixos/ directory not found in repo."

sudo cp -r "$REPO_DIR/nixos/." "$NIXOS_DIR/"
log "NixOS config files copied."

warn "hardware-configuration.nix was overwritten!"
warn "If your hardware config differs, restore it from backup:"
echo -e "${CYAN}    sudo cp $BACKUP_DIR/configuration.nix $NIXOS_DIR/${NC}"

# =============================================================================
# STEP 4 — Copy user config files
# =============================================================================
echo ""
info "Copying user config files to ~/.config ..."

mkdir -p "$HOME/.config"

copy_config() {
  local src="$REPO_DIR/$1"
  local dst="$HOME/.config/$1"
  if [ -d "$src" ]; then
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
# STEP 5 — Remind about required manual steps
# =============================================================================
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}  REQUIRED BEFORE REBUILDING:${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  1. Update GPU PCI addresses in ${CYAN}/etc/nixos/configuration.nix${NC}:"
echo -e "       GPU_PCI=\"0000:XX:XX.X\""
echo -e "       GPU_AUDIO=\"0000:XX:XX.X\""
echo ""
echo -e "  2. Update your git info in ${CYAN}/etc/nixos/home.nix${NC}:"
echo -e "       userName = \"your-name\";"
echo -e "       userEmail = \"your@email.com\";"
echo ""
echo -e "  3. Add your SSH key before rebuilding (SSH password auth is disabled):"
echo -e "${CYAN}       ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos${NC}"
echo ""
echo -e "  4. When ready, rebuild the system:"
echo -e "${CYAN}       sudo nixos-rebuild switch --flake /etc/nixos#nixos${NC}"
echo ""
echo -e "${RED}  DO NOT run nixos-rebuild until you have updated the GPU PCI  ${NC}"
echo -e "${RED}  addresses. Wrong addresses may cause display loss.            ${NC}"
echo ""
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
log "Installation complete. Review the steps above before rebuilding!"
echo ""

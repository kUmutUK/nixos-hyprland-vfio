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

echo ""
echo -e "${CYAN}==============================================================${NC}"
echo -e "${CYAN}   NixOS Hyprland Gaming + VFIO — Safe Setup Script${NC}"
echo -e "${CYAN}==============================================================${NC}"
echo ""
info "This script will backup your current NixOS configs and copy"
info "the new ones into ${NIXOS_DIR}."
info "It only performs safe variable replacements (GPU IDs, monitor, git)."
info "No destructive sed-hackery – any structural changes are shown for you to apply manually."
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
log "Environment OK."

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

# DÜZELTME (2026-10-04): `| head -1` erken kapanınca grep'e SIGPIPE (141)
# gönderiyor; `set -o pipefail` yüzünden betik burada sessizce ölüyordu.
# `grep -m1` aynı işi yapıp hattı düzgün kapatır.
gpu_line=$(lspci | grep -im1 -E "vga|3d|display" || true)
if echo "$gpu_line" | grep -qi "AMD\|ATI\|Radeon"; then
  GPU_VENDOR="amd"
elif echo "$gpu_line" | grep -qi "NVIDIA\|GeForce"; then
  GPU_VENDOR="nvidia"
elif echo "$gpu_line" | grep -qi "Intel"; then
  GPU_VENDOR="intel"
else
  GPU_VENDOR="unknown"
fi
log "GPU: $GPU_VENDOR"
echo -e "  ${CYAN}$gpu_line${NC}"
echo ""

if [[ "$CPU_VENDOR" != "amd" || "$GPU_VENDOR" != "amd" ]]; then
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  warn "This configuration is optimized for AMD CPU + AMD GPU."
  if [[ "$CPU_VENDOR" == "intel" ]]; then
    echo "  - Switch 'hardware.cpu.amd.updateMicrocode' → 'hardware.cpu.intel.updateMicrocode'"
    echo "  - Replace 'kvm-amd' → 'kvm-intel'"
    echo "  - Replace 'amd_iommu=on' → 'intel_iommu=on'"
    echo "  - Remove 'amd_pstate=active' kernel parameter"
  fi
  if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    echo "  - Bu repo NVIDIA'yı desteklemiyor; amdgpu varsayılan."
    echo "  - Remove AMD_VULKAN_ICD, RADV_PERFTEST variables"
    echo "  - Switch ollama package to ollama-cuda"
  elif [[ "$GPU_VENDOR" == "intel" ]]; then
    echo "  - Remove AMD-specific env vars and amdgpu.ppfeaturemask"
    echo "  - Switch ollama to pkgs.ollama (CPU only)"
  fi
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  read -rp "Press Enter to acknowledge these manual changes are needed..."
fi

# ─── User inputs ─────────────────────────────────────────
step "Configuration inputs"

echo "Detected VGA devices:"
lspci -nn | grep -iE "vga|3d|display" | sed 's/^/  /'
echo ""
read -rp "Enter GPU VGA PCI address (e.g. 0000:0b:00.0): " gpu_pci
read -rp "Enter GPU Audio PCI address (e.g. 0000:0b:00.1): " gpu_audio

# ─── IOMMU group preflight ─────────────────────────────────
step "IOMMU group check"
short_pci() { echo "$1" | sed -E 's/^0000://'; }
gpu_short="$(short_pci "$gpu_pci")"
iommu_dir="/sys/bus/pci/devices/0000:${gpu_short}/iommu_group"
if [ -e "$iommu_dir" ]; then
  group_num="$(basename "$(readlink -f "$iommu_dir")")"
  info "GPU (0000:${gpu_short}) IOMMU group: ${group_num}"
  echo "Bu gruptaki tüm PCI cihazları:"
  for dev in /sys/kernel/iommu_groups/"${group_num}"/devices/*; do
    dev_addr="$(basename "$dev")"
    lspci -nns "${dev_addr#0000:}" | sed 's/^/    /'
  done
  echo ""
  warn "Yukarıdaki listede GPU (${gpu_pci}) ve ses fonksiyonu (${gpu_audio})"
  warn "DIŞINDA bir cihaz varsa, o cihaz da VM'e verilmeden GPU'yu tek"
  warn "başına ayıramazsınız (ACS override gibi ek önlemler gerekir)."
  read -rp "Devam etmek istiyor musunuz? (yes/no): " iommu_confirm
  [[ "$iommu_confirm" != "yes" ]] && { info "Aborted."; exit 0; }
else
  warn "IOMMU group bilgisi okunamadı (${iommu_dir} yok)."
  warn "IOMMU'nun BIOS'ta etkin olduğundan emin olun; kontrol atlanıyor."
fi

echo ""
monitor_output="DP-3"
if command -v hyprctl &>/dev/null 2>&1 && hyprctl activeworkspace &>/dev/null 2>&1; then
  monitor_output=$(hyprctl monitors | grep -oPm1 '^Monitor \K\S+')
  log "Active Hyprland monitor: $monitor_output"
elif [ -d /sys/class/drm ]; then
  for card in /sys/class/drm/card*-*; do
    status=$(cat "$card/status" 2>/dev/null)
    if [ "$status" = "connected" ]; then
      monitor_output=$(basename "$card" | sed 's/card[0-9]*-//')
      log "DRM connected monitor: $monitor_output"
      break
    fi
  done
fi
read -rp "Monitor output name (for mpvpaper) [${monitor_output}]: " input_mon
[[ -n "$input_mon" ]] && monitor_output="$input_mon"

echo ""
read -rp "Hyprland monitor line (e.g. monitor = ,2560x1440@170,auto,1) [monitor = ,preferred,auto,1]: " hypr_mon_line
hypr_mon_line="${hypr_mon_line:-monitor = ,preferred,auto,1}"

echo ""
wallpaper_video="/home/localhost/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4"
read -rp "Wallpaper video path [${wallpaper_video}]: " input_video
[[ -n "$input_video" ]] && wallpaper_video="$input_video"

echo ""
read -rp "Git user name [Umpug]: " git_name
git_name="${git_name:-Umpug}"
read -rp "Git email [141457520+kUmutUK@users.noreply.github.com]: " git_email
git_email="${git_email:-141457520+kUmutUK@users.noreply.github.com}"

# ─── Backup ──────────────────────────────────────────────
step "Backing up current configurations"
mkdir -p "$BACKUP_DIR"
for src in "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" \
           "$NIXOS_FLAKE_DIR/configuration.nix" "$NIXOS_FLAKE_DIR/home.nix" \
           "$NIXOS_FLAKE_DIR/flake.nix" "$NIXOS_FLAKE_DIR/flake.lock" \
           "$NIXOS_DIR/hardware-configuration.nix" \
           "$NIXOS_FLAKE_DIR/hardware-configuration.nix"; do
    if [ -e "$src" ]; then
        cp -rL "$src" "$BACKUP_DIR/" 2>/dev/null && log "Backed up: $(basename "$src")" || true
    fi
done
log "Backup saved to $BACKUP_DIR"

# ─── File copy ──────────────────────────────────────────
step "Copying configuration files"
[[ ! -d "$REPO_DIR/nixos" ]] && error "nixos/ directory not found in repository."

sudo mkdir -p "$NIXOS_FLAKE_DIR"
for f in configuration.nix home.nix flake.nix flake.lock; do
    if [ -f "$REPO_DIR/nixos/$f" ]; then
        sudo cp "$REPO_DIR/nixos/$f" "$NIXOS_FLAKE_DIR/$f"
        log "Copied $f"
    else
        warn "Skipping missing file: $f"
    fi
done

if [ -d "$REPO_DIR/nixos/hooks" ]; then
    sudo rm -rf "$NIXOS_FLAKE_DIR/hooks"
    sudo cp -r "$REPO_DIR/nixos/hooks" "$NIXOS_FLAKE_DIR/hooks"
    sudo chmod 0755 "$NIXOS_FLAKE_DIR/hooks/qemu"
    log "Copied hooks/ (configuration.nix references ./hooks/qemu as a relative path)."

    sudo sed -i \
        -e "s|^GPU_PCI=\".*\"|GPU_PCI=\"${gpu_pci}\"|" \
        -e "s|^GPU_AUDIO=\".*\"|GPU_AUDIO=\"${gpu_audio}\"|" \
        "$NIXOS_FLAKE_DIR/hooks/qemu" && log "Hook script'teki GPU PCI adresleri de güncellendi."

    git -C "$NIXOS_FLAKE_DIR" update-index --no-skip-worktree hooks/qemu 2>/dev/null || true
    if git -C "$NIXOS_FLAKE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        git -C "$NIXOS_FLAKE_DIR" update-index --skip-worktree hooks/qemu 2>/dev/null \
            && log "hooks/qemu git'te skip-worktree olarak işaretlendi." \
            || warn "hooks/qemu için skip-worktree uygulanamadı."
    fi
else
    error "nixos/hooks/ directory not found — configuration.nix will fail to evaluate without it."
fi

# ─── VM XML PCI senkronizasyonu (yeni) ──────────────────
# Installer eskiden sadece hooks/qemu içindeki GPU_PCI/GPU_AUDIO'yu
# güncelliyordu; win10.xml'deki <hostdev> <source> <address> blokları
# ise sabit kalıyordu. Sonuç: hook yeni PCI adresini vfio-pci'ye bind
# ediyor ama libvirt hâlâ eski adresi aradığı için VM "device not found"
# ile başlamıyordu.
step "VM XML PCI senkronizasyonu"
if [ ! -f "$REPO_DIR/vm-xml/win10.xml" ]; then
  warn "vm-xml/win10.xml bulunamadı — XML'i elle düzenle."
elif ! command -v python3 >/dev/null 2>&1; then
  warn "python3 yok — vm-xml/win10.xml'i elle düzenle (bus/slot/function)."
else
  if python3 - "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win10.xml" <<'PYEOF'
import re, sys

gpu, aud, path = sys.argv[1], sys.argv[2], sys.argv[3]

def xml_attrs(addr):
    m = re.match(r'^([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$', addr)
    if not m:
        sys.exit(f"geçersiz PCI adresi: {addr}")
    d, b, s, f = m.groups()
    return f'domain="0x{d}" bus="0x{b}" slot="0x{s}" function="0x{f}"'

data = open(path).read()
pattern = re.compile(
    r'(<hostdev\b[^>]*>\s*<source>\s*<address\s+)([^/]+)(/>)',
    re.DOTALL)

addrs = [xml_attrs(gpu), xml_attrs(aud)]
counter = [0]

def repl(m):
    i = counter[0]
    counter[0] += 1
    return m.group(1) + (addrs[i] if i < len(addrs) else m.group(2)) + m.group(3)

new = pattern.sub(repl, data)
if counter[0] != 2:
    sys.exit(f"UYARI: XML'de {counter[0]} hostdev bulundu, 2 bekleniyordu. Dosya değiştirilmedi.")
open(path, 'w').write(new)
PYEOF
  then
    log "vm-xml/win10.xml → GPU=${gpu_pci}, Audio=${gpu_audio}"
    if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "$REPO_DIR" update-index --no-skip-worktree vm-xml/win10.xml 2>/dev/null || true
      git -C "$REPO_DIR" update-index --skip-worktree vm-xml/win10.xml 2>/dev/null \
        && log "vm-xml/win10.xml git'te skip-worktree olarak işaretlendi." \
        || warn "vm-xml/win10.xml için skip-worktree uygulanamadı."
    fi
  else
    warn "XML güncellenemedi — vm-xml/win10.xml'i elle düzenle."
  fi
fi

warn "hardware-configuration.nix was NOT copied (machine-specific — UUID'ler size özel)."
warn "Flake ./hardware-configuration.nix bekliyor, yani dosya şurada olmalı:"
echo -e "     ${CYAN}${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}"
echo ""
echo "   Mevcut sistemde zaten varsa:"
echo -e "     ${CYAN}sudo cp ${NIXOS_DIR}/hardware-configuration.nix ${NIXOS_FLAKE_DIR}/${NC}"
echo ""
echo "   Yeni kurulumda:"
echo -e "     ${CYAN}sudo cp /mnt/etc/nixos/hardware-configuration.nix ${NIXOS_FLAKE_DIR}/${NC}"
echo ""
echo "   Ya da elle oluşturun:"
echo -e "     ${CYAN}sudo nixos-generate-config --root /mnt${NC}"
echo -e "     ${CYAN}lsblk -f${NC}  # UUID'leri kontrol edin"

# ─── Btrfs snapshot subvolume ───────────────────────────
step "Btrfs snapshot subvolume"
if findmnt -no FSTYPE /home 2>/dev/null | grep -qi btrfs; then
  if [ -d /home/.snapshots ]; then
    log "/home/.snapshots already exists."
  else
    warn "/home/.snapshots is MISSING — snapper 'home' config and boot would both fail."
    sudo btrfs subvolume create /home/.snapshots
    log "Created /home/.snapshots."
  fi
else
  warn "/home is not a btrfs mount — skipping (snapper home config will not work)."
fi
echo ""

# ─── VM disk image ──────────────────────────────────────
step "VM disk image"
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu
if [ ! -f /var/lib/libvirt/images/win10new.qcow2 ]; then
  warn "VM diski yok — 120G qcow2 oluşturuluyor."
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G
fi
echo "  ISO dosyalarını /var/lib/libvirt/images/ altına kopyalayın:"
echo "    Win10_22H2_English_x64v1.iso"
echo "    virtio-win-0.1.285.iso"
echo ""

# ─── /nix/persist/home ──────────────────────────────────
step "Persistent storage directory"
if [ -d /nix/persist/home ]; then
  log "/nix/persist/home already exists."
else
  warn "/nix/persist/home is MISSING — home.persistence bind-mount would fail."
  sudo mkdir -p /nix/persist/home
  log "Created /nix/persist/home."
fi
echo ""

# ─── Variable substitution ──────────────────────────────
step "Applying safe variable substitutions"

HOME_NIX="$NIXOS_FLAKE_DIR/home.nix"
apply_var() {
  local var_name="$1" new_value="$2"
  if ! grep -qE "^[[:space:]]*${var_name}[[:space:]]*=" "$HOME_NIX"; then
    warn "Variable '${var_name}' not found in home.nix — skipped."
    return
  fi
  sudo sed -i -E "s|^([[:space:]]*${var_name}[[:space:]]*=).*;|\1 \"${new_value}\";|" "$HOME_NIX"
  if grep -qF "\"${new_value}\";" "$HOME_NIX"; then
    log "Set ${var_name}."
  else
    warn "Failed to verify substitution for '${var_name}'."
  fi
}

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
echo -e "${RED}  MANUAL STEPS BEFORE REBUILD${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
echo -e "${step_num}. Create the hashed password file:"
echo -e "   ${CYAN}mkpasswd --method yescrypt | sudo tee /etc/nixos/hashedPassword${NC}"
echo -e "   ${CYAN}sudo chmod 600 /etc/nixos/hashedPassword${NC}   ${YELLOW}(tee 644 acar)${NC}"
echo -e "   ${YELLOW}(mkpasswd, whois paketiyle gelir)${NC}"
((step_num++))

echo ""
echo -e "${step_num}. ${CYAN}VM'yi libvirt'e tanıt:${NC}"
echo -e "   ${CYAN}sudo mkdir -p /var/lib/libvirt/images${NC}"
echo -e "   ${CYAN}sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G${NC}"
echo -e "   ${YELLOW}ISO dosyalarını /var/lib/libvirt/images/ altına kopyalayın${NC}"
echo -e "   ${CYAN}sudo cp ${REPO_DIR}/vm-xml/win10.xml /var/lib/libvirt/ && sudo virsh define /var/lib/libvirt/win10.xml${NC}"
echo -e "   ${CYAN}virsh list --all${NC}   ${YELLOW}→ 'win10' shut off olarak görünmeli${NC}"
echo -e "   ${YELLOW}Not: PCI adresleri installer tarafından senkronize edildi.${NC}"
((step_num++))

echo ""
echo -e "${step_num}. Rebuild, then REBOOT:"
echo -e "   ${CYAN}sudo nixos-rebuild dry-activate --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo nixos-rebuild switch     --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo reboot${NC}"
echo -e "   ${YELLOW}REBOOT ZORUNLU: iommu=pt, amd_iommu=on, amdgpu.ppfeaturemask${NC}"
((step_num++))

echo ""
echo -e "${RED}  DO NOT rebuild until disk UUIDs are correct!${NC}"
echo ""
log "Setup complete."

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

# DÜZELTME (2026-10-06): burada doğrulama YOKTU. Aşağıdaki sed, girilen
# metni olduğu gibi hooks/qemu içindeki GPU_PCI/GPU_AUDIO satırlarına
# yazıyordu. "0000:0b:00" ya da "gpu" gibi hatalı bir girdi sessizce
# geçerli bir hook üretiyor, hata ancak çok sonra — VM başlatılırken —
# sysfs/fuser tarafında ve o zaman da "neden GPU passthrough olmadı"
# biçiminde çıkıyordu. VM XML senkronundaki Python bloğu zaten regex ile
# doğruluyordu; hook tarafı da aynı kuralı uyguluyor.
valid_pci() {
  [[ "$1" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]$ ]]
}

for _try in 1 2 3; do
  if valid_pci "$gpu_pci"; then break; fi
  warn "'$gpu_pci' geçerli bir PCI adresi değil — beklenen biçim: 0000:0b:00.0"
  if [ "$_try" -lt 3 ]; then read -rp "GPU PCI adresi: " gpu_pci; fi
done
valid_pci "$gpu_pci" || error "GPU PCI adresi 3 denemede de geçersiz — kurulum durduruluyor."

for _try in 1 2 3; do
  if valid_pci "$gpu_audio"; then break; fi
  warn "'$gpu_audio' geçerli bir PCI adresi değil — beklenen biçim: 0000:0b:00.1"
  if [ "$_try" -lt 3 ]; then read -rp "GPU Audio PCI adresi: " gpu_audio; fi
done
valid_pci "$gpu_audio" || error "GPU Audio PCI adresi 3 denemede de geçersiz — kurulum durduruluyor."

log "GPU PCI: $gpu_pci / Audio: $gpu_audio (biçim doğrulandı)"

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
monitor_output="DP-1"
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
read -rp "Hyprland monitor line (örn. monitor = DP-3,2560x1440@170,auto,1) [monitor = ${input_mon:-$monitor_output},preferred,auto,1]: " hypr_mon_line
hypr_mon_line="${hypr_mon_line:-monitor = ${input_mon:-$monitor_output},preferred,auto,1}"

echo ""
wallpaper_video="/home/localhost/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4"
read -rp "Wallpaper video path [${wallpaper_video}]: " input_video
[[ -n "$input_video" ]] && wallpaper_video="$input_video"

echo ""
# DÜZELTME: varsayılanlar bakımcının gerçek kimliğiydi ("Umpug" /
# 141457520+kUmutUK@...). Enter'a basılırsa tüm commit'ler BAŞKA BİRİYE
# atfediliyordu. Varsayılan artık home.nix ile aynı: changeme / you@example.com
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

# ─── hardware-configuration.nix (zorunlu girdi) ─────────────
# configuration.nix → `imports = [ ./hardware-configuration.nix ]` yaptığı için
# bu dosya YOKSA `nixos-rebuild` EVAL HATASI verir. Burada bilinçli olarak
# `builtins.pathExists` ile import'u koşullu yapmıyoruz: öyle bir guard hatayı
# susturur ve sistemi `fileSystems` tanımsız derler. Gürültülü eval hatası,
# sessiz yarım kurulumdan iyidir.
#
# install.sh ÇALIŞAN bir sistemde çalışır; yani disk UUID'leri zaten doğrudur
# ve nixos-generate-config'in ürettiği dosya tipik olarak /etc/nixos altındadır.
# "Farklı diske taşıma" senaryosu (--root /mnt) install.sh'ın kapsamı DIŞINDA —
# onu KURULUM.md yönetir.
#
# ÜZERİNE YAZMA KARARI (3 dal — sessiz seçim yok):
#   1) Hedef yoksa            → kopyala
#   2) Hedef varsa, aynıysa   → dokunma
#   3) Hedef varsa, FARKLIYSA → HEDEFİ KORU, farkı göster, değiştirme komutunu yaz
# Neden 3 "her koşuda taze kopyala" değil: flake-dir kopyası kullanıcının elle
# düzenlediği yer (swap UUID'si, ek alt hacim). Üstteki dosya yalnızca
# nixos-generate-config'in ham çıktısı — ikinci kurulumda onu ezip kullanıcının
# emeğini almak yanlış olur.
# Neden yine de "koru ve sus": ters yön de var — kullanıcı üstteki dosyayı
# yeniden ürettiyse sessizce bayatlamak da kötü. Bu yüzden iki yol da
# görünür, kararı kullanıcı verir.
#
# Karşılaştırma `cmp`/`diff` DEĞİL `$(cat …)` ile yapılıyor: `cmp` diffutils'ten
# gelir ve bu config'in systemPackages listesinde YOK. Dosyalar ~3 KB; cat
# (coreutils) yeter.
HARDWARE_MISSING=0
HARDWARE_SRC="$NIXOS_DIR/hardware-configuration.nix"
HARDWARE_DST="$NIXOS_FLAKE_DIR/hardware-configuration.nix"
if [ ! -f "$HARDWARE_SRC" ]; then
    HARDWARE_MISSING=1
    warn "hardware-configuration.nix YOK (${HARDWARE_SRC}) — rebuild EVAL HATASI verir."
    warn "Üretme komutu MANUAL STEPS listesine eklendi."
elif [ -f "$HARDWARE_DST" ]; then
    if [ "$(cat "$HARDWARE_SRC")" = "$(cat "$HARDWARE_DST")" ]; then
        log "hardware-configuration.nix zaten güncel — dokunulmadı."
    else
        warn "hardware-configuration.nix FARKLI — flake-dir'deki sürüm KORUNDU."
        warn "  üst (ham): ${HARDWARE_SRC}"
        warn "  alt (aktif): ${HARDWARE_DST}"
        warn "  farkı görmek için: sudo diff -u ${HARDWARE_SRC} ${HARDWARE_DST}"
        warn "  Üsttekini tercih ediyorsan:"
        warn "    sudo cp ${HARDWARE_SRC} ${HARDWARE_DST}"
    fi
else
    sudo cp "$HARDWARE_SRC" "$HARDWARE_DST"
    log "Copied hardware-configuration.nix (kaynak: ${HARDWARE_SRC})"
    warn "Bu, install.sh'in ÇALIŞTIĞI SİSTEMİN dosyası — UUID'ler o makineye ait."
    warn "Farklı bir diske taşınıyorsan bu dosya YANLIŞ olur. MANUAL STEPS'teki"
    warn "doğrulama adımını izle ve gerekirse nixos-generate-config ile üret."
fi

if [ -d "$REPO_DIR/nixos/hooks" ]; then
    sudo rm -rf "$NIXOS_FLAKE_DIR/hooks"
    sudo cp -r "$REPO_DIR/nixos/hooks" "$NIXOS_FLAKE_DIR/hooks"
    sudo chmod 0755 "$NIXOS_FLAKE_DIR/hooks/qemu"
    log "Copied hooks/ (configuration.nix references ./hooks/qemu as a relative path)."

    sudo sed -i \
        -e "s|^GPU_PCI=\".*\"|GPU_PCI=\"${gpu_pci}\"|" \
        -e "s|^GPU_AUDIO=\".*\"|GPU_AUDIO=\"${gpu_audio}\"|" \
        "$NIXOS_FLAKE_DIR/hooks/qemu" && log "Hook script'teki GPU PCI adresleri de güncellendi."

    # DÜZELTME (2026-10-05): buradaki `git update-index --skip-worktree`
    # kaldırıldı. /etc/nixos/nixos genelde bir git deposu DEĞİLDİR ve
    # olduğunda da skip-worktree, sonraki pull'da merge conflict çıkarır.
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
# DÜZELTME (2026-10-08): `command -v python3` KULLANICI'nın PATH'ini arar,
# `sudo python3` ise sudo'nun secure_path'ini (Defaults env_reset + secure_path).
# İkisi farklı çözümleme olduğu için kontrol "geçti" derken gerçek çalıştırma
# "command not found" ile patlayabiliyordu — ve patlama `if ... then` yapısı
# içinde yutulduğu için kullanıcı yalnızca "XML güncellenemedi" uyarısı
# alıyordu. NixOS'ta secure_path genelde /run/current-system/sw/bin içerir
# (yani çoğu kurulumda sorun çıkmaz) ama bu bir tesadüf, garanti değil:
# özelleştirilmiş bir sudoers `secure_path` ya da `env_reset` kapalıysa
# farklı sonuç verir.
# Çözüm: python3'ü BİR KERE kullanıcı PATH'inden mutlak yola çöz, sonra
# her yerde `sudo "$PYTHON3"` kullan. Böylece kontrol ve çalıştırma aynı
# binary'yi gösterir.
PYTHON3="$(command -v python3 || true)"
if [ ! -f "$REPO_DIR/vm-xml/win10.xml" ]; then
  warn "vm-xml/win10.xml bulunamadı — XML'i elle düzenle."
elif [ -z "$PYTHON3" ]; then
  warn "python3 yok — vm-xml/win10.xml'i elle düzenle (bus/slot/function)."
else
  # DÜZELTME (2026-10-05): script daha önce $REPO_DIR/vm-xml/win10.xml dosyasını
  # YERİNDE değiştirip değişikliği `git update-index --skip-worktree` ile
  # saklıyordu. Bu, "repo = değişmez şablon" değişmezini bozuyordu: sonraki
  # `git pull`'da skip-worktree merge conflict üretir, `git status` yalan söyler,
  # ve kurulum ikinci kez çalıştırılırsa aynı dosya tekrar yazılır.
  # Artık kaynak dosya SALT-OKUNUR kalıyor; patch'lenmiş XML doğrudan
  # libvirt'in kendi dizinine yazılıyor.
  PATCHED_XML="/var/lib/libvirt/win10.xml"
  # DÜZELTME: burada `sudo` yalnızca mkdir'de vardı; python3 normal kullanıcı
  # olarak çalışıp root'a ait /var/lib/libvirt/win10.xml'e yazmaya çalışıyordu
  # ve PermissionError alıyordu. Betik `if ... then` yapısı olduğu için hata
  # yutuluyor, kullanıcı yalnızca "XML güncellenemedi" uyarısı görüp
  # akıllıca elle düzenlemeye yöneliyordu — ama tam olarak bu sessiz hatanın
  # ürettiği felaket senaryosunda (hook yeni PCI adresine bind oluyor, libvirt
  # eski adresi arıyor → "device not found") kalıyorsun.
  # apply_var() zaten `sudo python3` kullanıyor; aynı desen buraya da uygulanır.
  if sudo mkdir -p /var/lib/libvirt && sudo "$PYTHON3" - "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win10.xml" "$PATCHED_XML" <<'PYEOF'
import re, sys

gpu, aud, src, dst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def xml_attrs(addr):
    m = re.match(r'^([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$', addr)
    if not m:
        sys.exit(f"geçersiz PCI adresi: {addr}")
    d, b, s, f = m.groups()
    return f'domain="0x{d}" bus="0x{b}" slot="0x{s}" function="0x{f}"'

data = open(src, encoding="utf-8").read()
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

# DÜZELTME (2026-10-05): 0 veya 3+ hostdev durumunda eski kod sessizce
# sys.exit(1) veriyordu. 2 GPU + NIC geçiren bir kurulumda bu, hook'un yeni
# PCI adresine bind olup libvirt'ın eski adresi aradığı ("device not found")
# tam olarak felaket senaryosuydu — ama kullanıcı UYARI bile görmüyordu.
# Artık: 0 hostdev = gerçek hata (çık); 3+ = UYAR ve İLK 2'yi yaz
# (kalanları elle düzenlemesi için adreslerini stdout'a bas).
n = counter[0]
if n == 0:
    sys.exit("HATA: XML'de PCI hostdev bulunamadı (0 eşleşme). Dosya yazılmadı.")
if n != 2:
    print(f"UYARI: XML'de {n} PCI hostdev bulundu, 2 bekleniyordu.", file=sys.stderr)
    print(f"UYARI: SADECE ilk 2'si yazıldı (GPU={gpu}, Audio={aud}).", file=sys.stderr)
    print(f"UYARI: {n-2} hostdev elle düzenilmeli — her birinin <source><address>",
          file=sys.stderr)
    print("UYARI: satırı aşağıdaki komutla doğrula:", file=sys.stderr)
    print(f"  grep -n -A3 '<hostdev' {dst}", file=sys.stderr)

open(dst, "w", encoding="utf-8").write(new)
print(f"OK: {n} hostdev bulundu, {min(n,2)} tanesi güncellendi -> {dst}")
PYEOF
  then
    log "vm-xml/win10.xml -> ${PATCHED_XML} (GPU=${gpu_pci}, Audio=${gpu_audio})"
    log "Kaynak repo dosyası DEĞİŞTİRİLMEDİ."
    echo -e "     ${CYAN}sudo virsh define ${PATCHED_XML}${NC}"
  else
    warn "XML güncellenemedi — win10.xml'i elle düzenle."
  fi
fi

# `hardware-configuration.nix` artık yukarıda "Copying configuration files"
# bölümünde ele alınıyor (kopyalandı ya da MANUAL STEPS'e madde düştü).
# Buradaki eski uyarı bloğu kaldırıldı: aynı konuyu iki kez söylüyordu ve
# "Mevcut sistemde zaten varsa" komutu artık otomatik çalışıyordu.

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

# DÜZELTME (2026-10-05): bu fonksiyon kullanıcı girdisini doğrudan `sed -E`
# ifadesine gömerdi. Gerçek test sonuçları:
#   git name "DP-3 & HDMI" -> home.nix'in içine eşleşen satır KOPYALANIYOR
#                             (& sed'de "eşleşen metin" anlamına gelir) ve
#                             geçersiz Nix metni oluşuyor.
#   herhangi bir "|"      -> `sed: unknown option to 's'` ve set -e yüzünden
#                             script tam da bu adımda ÖLÜYOR.
#   "C:\path"             -> sessizce "C:path" oluyor, backslash yutuluyor.
# Üstelik sed bozuk dosyayı YAZMIŞ olduğu için sondaki "Failed to verify"
# uyarısı sadece haber veriyor; bozuk home.nix diskte kalıyor.
#
# Yerine python3: satır bazlı regex değiştirme yapıyor, shell meta karakterleri
# değer olarak işleniyor, yazma atomik. python3 artık
# environment.systemPackages'ta olduğu için (XML senkronu düzeltmesiyle)
# bu sistemde garanti edilebilir.
# DÜZELTME (2026-10-08): buradaki `command -v python3` KULLANICI PATH'ini
# ararken apply_var() sudo altında çalışıyordu. İkisi farklı çözümleme
# olduğundan kontrol geçerken çalıştırma patlayabiliyordu. Yukarıda
# $PYTHON3 zaten mutlak yola çözüldü; aynı değişkeni kullan.
if [ -z "$PYTHON3" ]; then
    error "python3 gerekli ama PATH'te yok — home.nix güvenle güncellenemez."
fi

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

escaped = value.replace("\\", "\\\\").replace('"', '\\"')

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
    warn "Failed to substitute '${var_name}' — home.nix DEĞİŞTİRİLMEDİ."
    return 1
  fi
  log "Set ${var_name}."
}

if [ "$git_name" = "changeme" ] || [ "$git_email" = "you@example.com" ]; then
  warn "Git kimliği 'changeme'/'you@example.com' olarak kaldı — commit'ler"
  warn "bu sahte kimlikle etiketlenecek. Kendi bilgilerini girmek için"
  warn "home.nix içindeki gitName / gitEmail değerlerini elle değiştir."
fi
apply_var "gitName" "$git_name"
apply_var "gitEmail" "$git_email"
apply_var "monitorOutput" "$monitor_output"

# DÜZELTME (2026-10-08): `hyprlandMonitorLine` artık home.nix'te
# `monitorOutput`'tan TÜRETİLİYOR (tek kaynak). apply_var regex'i o satırı
# bulup TAMAMINI ezerdi, yani deploy edilen dosyada
#   hyprlandMonitorLine = "monitor = DP-3,preferred,auto,1";
# kalırdı ve `${monitorOutput}` kaybolurdu — tek-kaynak ilişkisi kurulumda
# kayboluyordu. home.nix'in varsayılanı zaten `monitor = ${monitorOutput},
# preferred,auto,1` ürettiği için varsayılan durumda YAZMAK GEREK YOK.
#
# Ama tamamen silmek de doğru değil: çok monitörlü kurulumda kullanıcı
# çözünürlük/yenileme hızı da yazmak isteyebilir
# (örn. "monitor = DP-1,2560x1440@170,auto,1") ve o zaman türetme bilinçli
# olarak geçersiz kılınır. Bu yüzden: yalnızca kullanıcı GERÇEKTEN farklı
# bir satır verdiyse yaz.
#
# Boş bırakıldığında (üzeri + Enter) türetme korunur; özel satır girildiğinde
# apply_var onu yazar. Kullanıcıya ne olacağını da söylüyoruz.
hypr_mon_default="monitor = ${input_mon:-$monitor_output},preferred,auto,1"
if [ "$hypr_mon_line" = "$hypr_mon_default" ]; then
  info "Hyprland monitor satırı varsayılandan aynı — home.nix'te monitorOutput'tan türetiliyor, yazılmadı."
else
  apply_var "hyprlandMonitorLine" "$hypr_mon_line"
  info "Özel Hyprland monitor satırı yazıldı (türetme bu kurulumda bilinçli olarak geçersiz kılındı)."
fi
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

if [ "$HARDWARE_MISSING" -eq 1 ]; then
  # Dosya yok: configuration.nix onu import ettiği için bu madde OPSIYONEL
  # değil. Üretme komutunda `>` DEĞİL `| sudo tee` kullanıyoruz — `sudo cmd > yol`
  # deseni yönlendirmeyi sudo'nun DIŞINDA bırakır, yani /etc/nixos'a yazma
  # yetkisi olmayan kullanıcıda "Permission denied" verir. (Bu sınıftaki ikinci
  # hatadır; birincisi PYTHON3'ün kullanıcı PATH'i ile sudo secure_path'i
  # arasında çözümlenmesiydi.)
  echo -e "${step_num}. ${RED}hardware-configuration.nix ÜRETİLMELİ${NC} (${HARDWARE_SRC} yok):"
  echo -e "   ${CYAN}sudo nixos-generate-config --show-hardware-config${NC}"
  echo -e "     ${CYAN}| sudo tee ${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}"
  echo "   ${YELLOW}(| sudo tee: '>' yetki hatası verir — yönlendirme sudo dışında kalır)${NC}"
  echo "   ${YELLOW}Farklı diske taşıyorsan: --show-hardware-config yerine${NC}"
  echo "   ${YELLOW}  sudo nixos-generate-config --root /mnt --show-hardware-config${NC}"
  echo "   Bu olmadan rebuild EVAL HATASI verir (configuration.nix onu import ediyor)."
  ((step_num++))
else
  echo -e "${step_num}. Doğrula: ${CYAN}${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}"
  echo "   ${YELLOW}Bu dosya install.sh'in çalıştığı SİSTEMDEN kopyalandı.${NC}"
  echo "   ${YELLOW}Farklı bir diske taşıyıyorsan YANLIŞTIR — aşağıdaki üretme${NC}"
  echo "   ${YELLOW}komutuyla kendi makinenin dosyasıyla değiştir:${NC}"
  echo -e "     ${CYAN}sudo nixos-generate-config --root /mnt --show-hardware-config${NC}"
  echo -e "     ${CYAN}| sudo tee ${NIXOS_FLAKE_DIR}/hardware-configuration.nix${NC}"
  echo "   lsblk -f   # beklenen UUID'lerle eşleşiyor mu?"
  ((step_num++))
fi

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
echo -e "   ${CYAN}sudo virsh define /var/lib/libvirt/win10.xml${NC}"
# E1: <nvram template=...> yalnızca NVRAM ilk oluşturulurken okunur. Daha önce
# tanımlanmış bir 'win10' varsa ve /var/lib/libvirt/qemu/nvram/win10_VARS.fd
# eski (hatalı) şablondan üretilmişse, XML'i düzeltmek onu yenilemez —
# kullanıcı reboot eder, hiçbir şey değişmemiş görür ve düzeltmeyi geri alır.
# --nvram OLMADAN undefine NVRAM dosyasını korur ve tuzağı çözmez.
if virsh dominfo win10 >/dev/null 2>&1; then
  echo -e "   ${YELLOW}⚠ win10 daha önce tanımlanmış. Eğer NVRAM eski şablondan${NC}"
  echo -e "   ${YELLOW}  üretildiyse XML düzeltmesi işe yaramaz — NVRAM'ı sıfırla:${NC}"
  echo -e "   ${CYAN}  sudo virsh undefine win10 --nvram${NC}   ${YELLOW}(--nvram şart!)${NC}"
  echo -e "   ${YELLOW}  sonra yukarıdaki 'virsh define' satırını tekrar çalıştır.${NC}"
fi
echo -e "   ${CYAN}virsh list --all${NC}   ${YELLOW}→ 'win10' shut off olarak görünmeli${NC}"
echo -e "   ${CYAN}(XML yukarıdaki adımda zaten /var/lib/libvirt/win10.xml'e yazıldı;${NC}"
echo -e "    ${CYAN}3+ hostdev varsa UYARI'ya dikkat et — fazlasını elle düzenle.)${NC}"
((step_num++))

echo ""
echo -e "${step_num}. Rebuild, then REBOOT:"
echo -e "   ${CYAN}sudo nixos-rebuild dry-activate --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo nixos-rebuild switch     --flake ${NIXOS_FLAKE_DIR}#nixos${NC}"
echo -e "   ${CYAN}sudo reboot${NC}"
echo -e "   ${YELLOW}REBOOT ZORUNLU: iommu=pt, amdgpu.ppfeaturemask${NC}"
((step_num++))

echo ""
echo -e "${RED}  DO NOT rebuild until disk UUIDs are correct!${NC}"
echo ""
log "Setup complete."

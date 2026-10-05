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

# --force yalnızca IOMMU gate'ini aşar. Normalde izole olmayan bir grup
# kurulumu durdurur; --force bunu bilinçli bir kullanıcı kararı yapar.
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=1 ;;
    -h|--help)
      echo "Usage: ./install.sh [--force]"
      echo "  --force   IOMMU group beklenmedik cihaz içeriyorsa da devam et."
      echo "            Yalnızca ACS override gibi önlemler biliyorsanız kullanın."
      exit 0 ;;
    *)
      echo "Unknown option: $arg (see --help)" >&2
      exit 2 ;;
  esac
done

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
# Kullanıcı "0b:00.0" / "0000:0b:00.0" / "00000b:00.0" yazabiliyor; sysfs
# daima tam "0000:bb:dd.f" biçiminde. Karşılaştırma yapılmadan önce
# hepsini tek biçime indiriyoruz, yoksa "temiz grup" kontrolü yanlış negatif
# üretir.
norm_pci() {
  local p="${1,,}"
  p="${p#0000:}"
  printf '0000:%s' "$p"
}
gpu_short="$(short_pci "$gpu_pci")"
iommu_dir="/sys/bus/pci/devices/0000:${gpu_short}/iommu_group"
if [ -e "$iommu_dir" ]; then
  group_num="$(basename "$(readlink -f "$iommu_dir")")"
  info "GPU (0000:${gpu_short}) IOMMU group: ${group_num}"
  echo "Bu gruptaki tüm PCI cihazları:"
  unexpected=()
  for dev in /sys/kernel/iommu_groups/"${group_num}"/devices/*; do
    [ -e "$dev" ] || continue
    dev_addr="$(basename "$dev")"
    lspci -nns "${dev_addr#0000:}" | sed 's/^/    /'
    case "$(norm_pci "$dev_addr")" in
      "$(norm_pci "$gpu_pci")"|"$(norm_pci "$gpu_audio")") ;;
      *) unexpected+=("$dev_addr") ;;
    esac
  done
  echo ""
  if [ "${#unexpected[@]}" -eq 0 ]; then
    log "IOMMU group temiz — yalnızca GPU ve GPU ses fonksiyonu var."
  elif [ "$FORCE" -eq 1 ]; then
    warn "IOMMU group izole DEĞİL: ${#unexpected[@]} beklenmedik cihaz."
    for u in "${unexpected[@]}"; do
      warn "    $u  $(lspci -nns "${u#0000:}" 2>/dev/null | cut -d' ' -f2-)"
    done
    warn "--force verildiği için devam ediliyor. İzolasyon garantisi yok."
  else
    error "IOMMU group izole DEĞİL — kurulum durduruldu."
    echo -e "  ${RED}Beklenmedik ${#unexpected[@]} cihaz:${NC}"
    for u in "${unexpected[@]}"; do
      echo "    $u  $(lspci -nns "${u#0000:}" 2>/dev/null | cut -d' ' -f2-)"
    done
    echo ""
    warn "GPU + ses dışındaki cihazlar da VM'e verilmeden tek GPU'yu"
    warn "ayıramazsınız: VFIO bind ya başarısız olur ya da beklenmedik"
    warn "cihazlar host tarafında erişilemez hale gelir (boot sonrası sürpriz)."
    echo ""
    info "Düzeltme yolları:"
    echo "    1. BIOS/UEFI'de IOMMU'yu (AMD-Vi / Intel VT-d) açın; yeni anakart"
    echo "       anakartlar genelde IOMMU'yu varsayılan AÇIK gelir."
    echo "    2. 'lspci -nnk' ile beklenmedik cihazları tanıyın. Bunlar ayrı bir"
    echo "       PCIe root porta bağlıysa fiziksel olarak taşımak genelde tek"
    echo "       gerçek çözümdür."
    echo "    3. Bu adımı bilinçli olarak atlamak istiyorsanız: ./install.sh --force"
    exit 1
  fi
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

if [ -d "$REPO_DIR/nixos/hooks" ]; then
    sudo rm -rf "$NIXOS_FLAKE_DIR/hooks"
    sudo cp -r "$REPO_DIR/nixos/hooks" "$NIXOS_FLAKE_DIR/hooks"
    sudo chmod 0755 "$NIXOS_FLAKE_DIR/hooks/qemu"
    log "Copied hooks/ (configuration.nix references ./hooks/qemu as a relative path)."

    # DÜZELTME (2026-10-05): buradaki `sed -i` ile değişkenler
    # kaçırılmadan konuşturuluyordu. sed replacement metninde `\`, `&` ve
    # `|` karakterleri ÖZEL anlam taşır; kullanıcı bunları içeren bir PCI
    # adresi (ya da beklenmedik bir karakter) yazarsa hook sessizce bozulur.
    # PCI adresi zaten regex ile doğrulanabilir olduğu için: önce formatı
    # doğrula, sonra Python ile hedefli ve kaçırılabilir bir yaz.
    if ! printf '%s\n%s\n' "$gpu_pci" "$gpu_audio" | grep -qEv '^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]$'; then
      error "PCI adresi biçimi geçersiz: beklenen '0000:0b:00.0'."
    fi
    if python3 - "$gpu_pci" "$gpu_audio" "$NIXOS_FLAKE_DIR/hooks/qemu" <<'PYEOF2'
import re, sys
gpu, aud, path = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(path, encoding="utf-8").read()
for var, val in (("GPU_PCI", gpu), ("GPU_AUDIO", aud)):
    pat = re.compile(r'^(%s=)(")[^"]*(")' % var, re.M)
    data, n = pat.subn(lambda m: m.group(1) + m.group(2) + val + m.group(3), data)
    if n != 1:
        sys.exit(f"beklenen tek {var}= satırı bulunamadı ({n} eşleşme)")
open(path, "w", encoding="utf-8").write(data)
print("OK")
PYEOF2
    then
      log "Hook script'teki GPU PCI adresleri de güncellendi."
    else
      error "hooks/qemu patch başarısız — dosya bozulmadı, elle düzeltin."
    fi

    # DÜZELTME (2026-10-05): buradaki `git update-index --skip-worktree`
    # kaldırıldı. /etc/nixos/nixos genelde bir git deposu DEĞİLDİR ve
    # olduğunda da skip-worktree, sonraki pull'da merge conflict çıkarır.
else
    error "nixos/hooks/ directory not found — configuration.nix will fail to evaluate without it."
fi

# ─── VM XML PCI senkronizasyonu (yeni) ──────────────────
# Installer eskiden sadece hooks/qemu içindeki GPU_PCI/GPU_AUDIO'yu
# güncelliyordu; win11.xml'deki <hostdev> <source> <address> blokları
# ise sabit kalıyordu. Sonuç: hook yeni PCI adresini vfio-pci'ye bind
# ediyor ama libvirt hâlâ eski adresi aradığı için VM "device not found"
# ile başlamıyordu.
step "VM XML PCI senkronizasyonu"
if [ ! -f "$REPO_DIR/vm-xml/win11.xml" ]; then
  warn "vm-xml/win11.xml bulunamadı — XML'i elle düzenle."
elif ! command -v python3 >/dev/null 2>&1; then
  warn "python3 yok — vm-xml/win11.xml'i elle düzenle (bus/slot/function)."
else
  # DÜZELTME (2026-10-05): script daha önce $REPO_DIR/vm-xml/win11.xml dosyasını
  # YERİNDE değiştirip değişikliği `git update-index --skip-worktree` ile
  # saklıyordu. Bu, "repo = değişmez şablon" değişmezini bozuyordu: sonraki
  # `git pull`'da skip-worktree merge conflict üretir, `git status` yalan söyler,
  # ve kurulum ikinci kez çalıştırılırsa aynı dosya tekrar yazılır.
  # Artık kaynak dosya SALT-OKUNUR kalıyor; patch'lenmiş XML doğrudan
  # libvirt'in kendi dizinine yazılıyor.
  PATCHED_XML="/var/lib/libvirt/win11.xml"
  if sudo mkdir -p /var/lib/libvirt && python3 - "$gpu_pci" "$gpu_audio" "$REPO_DIR/vm-xml/win11.xml" "$PATCHED_XML" <<'PYEOF'
import re, sys

gpu, aud, src, dst = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

def xml_attrs(addr):
    m = re.match(r'^([0-9a-fA-F]{4}):([0-9a-fA-F]{2}):([0-9a-fA-F]{2})\.([0-9a-fA-F])$', addr)
    if not m:
        sys.exit(f"geçersiz PCI adresi: {addr}")
    d, b, s, f = m.groups()
    return f'domain="0x{d}" bus="0x{b}" slot="0x{s}" function="0x{f}"'

data = open(src, encoding="utf-8").read()

# DÜZELTME (2026-10-05) — placeholder tabanlı eşleştirme.
# Önceden "ilk iki PCI <hostdev>" varsayımı vardı. Bu, XML'e ileride bir
# NIC/USBTL PCI hostdev ya da ikinci bir GPU eklenmesi HEMEN yanlış cihazı
# hedeflerdi (sessizce). Artık XML'de `GPU_PCI_PLACEHOLDER` ve
# `GPU_AUDIO_PCI_PLACEHOLDER` yorum işaretçileri var; eşleştirme yalnızca
# bunun hemen ardından gelen hostdev bloğuna yapılır, yani sıra önemsiz.
#
# Geriye dönük uyum: işaretçi yoksa eski sıra-tabanlı davranışa düşülür
# (kullanıcının elde ettiği eski bir XML'i yine de işleyebilmek için).
# DİKKAT: re.search(...)[start:] üzerinde çalışan match nesnesinin
# .start()/.end() ofsetleri O ALT DİZE GÖRELİDİR. Doğrudan new[...] içinde
# kullanılırsa dosyanın yanlış bir yerine yazılır ve XML parçalanır. Bu yüzden
# mutlak ofset: marker_sonu + match.start(2).
def hostdev_after(marker):
    m = re.search(r'<!--\s*' + marker + r'.*?-->', data, re.DOTALL)
    if not m:
        return None
    h = re.search(
        r'(<hostdev\b[^>]*>\s*<source>\s*<address\s+)([^/]+?)(/>)',
        data[m.end():], re.DOTALL)
    if not h:
        return None
    return (m.end() + h.start(2), m.end() + h.end(2))

targets = [("GPU_PCI_PLACEHOLDER", gpu), ("GPU_AUDIO_PCI_PLACEHOLDER", aud)]
new = data
counter = [0]
used_fallback = False
for marker, addr in targets:
    span = hostdev_after(marker)
    if span:
        a, b = span
        new = new[:a] + xml_attrs(addr) + new[b:]
        counter[0] += 1

if counter[0] == 0:
    # Eski XML şeması: işaretçi yok, sıra-tabanlı fallback.
    used_fallback = True
    pattern = re.compile(
        r'(<hostdev\b[^>]*>\s*<source>\s*<address\s+)([^/]+?)(/>)',
        re.DOTALL)
    addrs = [xml_attrs(gpu), xml_attrs(aud)]
    c = [0]
    def repl(m):
        i = c[0]; c[0] += 1
        return m.group(1) + (addrs[i] if i < len(addrs) else m.group(2)) + m.group(3)
    new = pattern.sub(repl, data)
    counter[0] = c[0]

# DÜZELTME (2026-10-05): 0 veya 3+ hostdev durumunda eski kod sessizce
# sys.exit(1) veriyordu. 2 GPU + NIC geçiren bir kurulumda bu, hook'un yeni
# PCI adresine bind olup libvirt'ın eski adresi aradığı ("device not found")
# tam olarak felaket senaryosuydu — ama kullanıcı UYARI bile görmüyordu.
# Artık: 0 hostdev = gerçek hata (çık); 3+ = UYAR ve İLK 2'yi yaz
# (kalanları elle düzenlemesi için adreslerini stdout'a bas).
n = counter[0]
if n == 0:
    sys.exit("HATA: XML'de GPU/GPU-audio PCI hostdev bulunamadı. Dosya yazılmadı.")
if used_fallback:
    print("UYARI: XML'de GPU_PCI_PLACEHOLDER işaretçisi yok — eski şema olduğu",
          file=sys.stderr)
    print("UYARI: için sıra-tabanlı (ilk 2 hostdev) eşleştirme kullanıldı.",
          file=sys.stderr)
    print("UYARI: İleride NIC/USB PCI hostdev eklersen bu yanlış cihazı",
          file=sys.stderr)
    print("UYARI: hedefler. vm-xml/win11.xml'i yeni şemaya geçirin.", file=sys.stderr)
    if n > 2:
        print(f"UYARI: {n} PCI hostdev bulundu; SADECE ilk 2'si yazıldı.",
              file=sys.stderr)
        print(f"UYARI: Kalan {n-2} tanesini elle doğrulayın:", file=sys.stderr)
        print(f"  grep -n -A3 '<hostdev' {dst}", file=sys.stderr)

open(dst, "w", encoding="utf-8").write(new)
print(f"OK: {n} hostdev bulundu, {min(n,2)} tanesi güncellendi -> {dst}")
PYEOF
  then
    log "vm-xml/win11.xml -> ${PATCHED_XML} (GPU=${gpu_pci}, Audio=${gpu_audio})"
    log "Kaynak repo dosyası DEĞİŞTİRİLMEDİ."
    echo -e "     ${CYAN}sudo virsh define ${PATCHED_XML}${NC}"
  else
    warn "XML güncellenemedi — win11.xml'i elle düzenle."
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
  if ! command -v btrfs &>/dev/null; then
    warn "btrfs-progs yok — /home/.snapshots doğrulanamıyor."
    warn "Kurulumdan sonra elle kontrol edin: btrfs subvolume show /home/.snapshots"
  elif [ -d /home/.snapshots ]; then
    # DÜZELTME: `-d /home/.snapshots` yalnızca "dizin var" der. Snapper'ın
    # ve `neededForBoot = true` olan mount'un gerçekten çalışması için
    # orada bir BTRFS SUBVOLUME olması şart; düz bir dizin snapshot üretmez
    # ve boot sırasında "not a btrfs subvolume" hatası verir. Bu yüzden
    # btrfs'in kendisine soruyoruz.
    if sudo btrfs subvolume show /home/.snapshots >/dev/null 2>&1; then
      log "/home/.snapshots mevcut ve gerçek bir Btrfs subvolume."
    elif [ -n "$(ls -A /home/.snapshots 2>/dev/null)" ]; then
      error "/home/.snapshots bir Btrfs subvolume DEĞİL ve içi boş değil."
      echo -e "  ${RED}Bu dizin normal bir klasör; içinde veri var, silinmedi.${NC}"
      echo "    • İçeriği yedekleyip kaldırın, sonra kurulumu tekrar çalıştırın:"
      echo "        sudo mv /home/.snapshots /home/.snapshots.bak"
      echo "    • Ya da mevcut kurulumun subvolume şemasını elle oluşturun:"
      echo "        sudo btrfs subvolume create /home/.snapshots"
    else
      warn "/home/.snapshots boş bir dizin, subvolume değil — düzeltiliyor."
      sudo rmdir /home/.snapshots
      sudo btrfs subvolume create /home/.snapshots
      log "Created /home/.snapshots as a real subvolume."
    fi
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
if [ ! -f /var/lib/libvirt/images/win11new.qcow2 ]; then
  warn "VM diski yok — 120G qcow2 oluşturuluyor."
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11new.qcow2 120G
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

if [ "$git_name" = "changeme" ] || [ "$git_email" = "you@example.com" ]; then
  warn "Git kimliği 'changeme'/'you@example.com' olarak kaldı — commit'ler"
  warn "bu sahte kimlikle etiketlenecek. Kendi bilgilerini girmek için"
  warn "home.nix içindeki gitName / gitEmail değerlerini elle değiştir."
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
echo -e "   ${CYAN}sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win11new.qcow2 120G${NC}"
echo -e "   ${YELLOW}ISO dosyalarını /var/lib/libvirt/images/ altına kopyalayın${NC}"
echo -e "   ${CYAN}sudo virsh define /var/lib/libvirt/win11.xml${NC}"
echo -e "   ${CYAN}virsh list --all${NC}   ${YELLOW}→ 'win11' shut off olarak görünmeli${NC}"
echo -e "   ${CYAN}(XML yukarıdaki adımda zaten /var/lib/libvirt/win11.xml'e yazıldı;${NC}"
echo -e "    ${CYAN}3+ hostdev varsa UYARI'ya dikkat et — fazlasını elle düzenle.)${NC}"
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

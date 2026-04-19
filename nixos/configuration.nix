{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ============================================================
  # Systemd Tmpfiles
  # ============================================================
  systemd.tmpfiles.rules = [
    "d /var/log/libvirt 0755 root root -"
    "d /etc/libvirt/hooks 0755 root root -"
    "r! /var/log/libvirt/vfio-v3.log - - - -"
  ];

  # ============================================================
  # Libvirt Hook Script
  # system.activationScripts gerçek dosya yazar → libvirt çalıştırır.
  # ============================================================
  system.activationScripts.libvirtHook = {
    text = ''
      mkdir -p /etc/libvirt/hooks
      cat > /etc/libvirt/hooks/qemu << 'HOOKEOF'
#!/usr/bin/env bash

LOGFILE="/var/log/libvirt/vfio.log"
GPU_VFIO_PATH="/sys/bus/pci/drivers/vfio-pci"
GPU_AMDGPU_PATH="/sys/bus/pci/drivers/amdgpu"
GPU_PCI="0000:0b:00.0"
GPU_AUDIO="0000:0b:00.1"
VENDOR_RESET_PATH="/sys/bus/pci/devices"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

bind_driver() {
  local pci=$1
  local driver=$2
  local i=0
  while [ $i -lt 5 ]; do
    echo "$pci" > "$driver/bind" 2>/dev/null && return 0
    log "   bind deneme $((i+1))/5 başarısız: $pci -> $(basename $driver)"
    sleep 1
    i=$((i + 1))
  done
  log "   [ERROR] $pci -> $(basename $driver): 5 denemede bind başarısız."
  return 1
}

unbind_driver() {
  local pci=$1
  local current_driver
  current_driver=$(readlink "$VENDOR_RESET_PATH/$pci/driver" 2>/dev/null | xargs basename 2>/dev/null)
  if [ -n "$current_driver" ]; then
    log "   Unbinding $pci from $current_driver"
    echo "$pci" > "/sys/bus/pci/drivers/$current_driver/unbind" 2>/dev/null
    sleep 0.5
  else
    log "   $pci zaten bağsız, atlanıyor"
  fi
}

vendor_reset_gpu() {
  log "   GPU vendor-reset tetikleniyor: $GPU_PCI"
  if [ -f "$VENDOR_RESET_PATH/$GPU_PCI/reset" ]; then
    echo 1 > "$VENDOR_RESET_PATH/$GPU_PCI/reset" 2>/dev/null \
      && log "   vendor-reset: OK" \
      || log "   vendor-reset: FAILED (devam ediliyor)"
    sleep 0.5
  else
    log "   vendor-reset sysfs yolu bulunamadi, atlanıyor"
  fi
}

reset_framebuffer() {
  log "   Framebuffer konsolları sıfırlanıyor..."
  for dev in /sys/class/vtconsole/vtcon*; do
    [ -d "$dev" ] || continue
    echo 0 > "$dev/bind" 2>/dev/null
  done
  sleep 0.5
  echo 1 > /sys/class/vtconsole/vtcon0/bind 2>/dev/null
  sleep 0.3
  if [ -d /sys/class/vtconsole/vtcon1 ]; then
    echo 1 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null \
      && log "   vtcon1 (fbcon) bağlandı: OK" \
      || log "   vtcon1 bind başarısız"
  fi
  sleep 0.5
  chvt 2 2>/dev/null
  sleep 0.3
  chvt 1 2>/dev/null
  sleep 0.5
  log "   Framebuffer reset tamamlandı"
}

GUEST="$1"
OPERATION="$2"
SUBOP="$3"
EXTRA="$4"

log "=========================================="
log "Hook: guest=$GUEST op=$OPERATION subop=$SUBOP extra=$EXTRA"

if [[ "$GUEST" == "win10" ]] || [[ "$GUEST" == "win11" ]]; then
  case "$OPERATION" in

    prepare)
      log "=== [PREPARE] GPU VM'e veriliyor ==="
      for pci in $GPU_PCI $GPU_AUDIO; do
        unbind_driver "$pci"
      done
      modprobe vfio-pci 2>/dev/null
      echo "1002 73df" > "$GPU_VFIO_PATH/new_id" 2>/dev/null
      echo "1002 ab28" > "$GPU_VFIO_PATH/new_id" 2>/dev/null
      for pci in $GPU_PCI $GPU_AUDIO; do
        bind_driver "$pci" "$GPU_VFIO_PATH" \
          && log "   $pci -> vfio-pci: OK" \
          || log "   $pci -> vfio-pci: FAILED"
      done
      log "[PREPARE] GPU VM'e verildi"
      ;;

    start)
      log "=== [START] VM başlatılıyor ==="
      ;;

    started)
      log "=== [STARTED] VM çalışıyor ==="
      ;;

    stopped)
      log "=== [STOPPED] VM durdu, sürücüler çözülüyor ==="
      timeout=15
      i=0
      while pgrep -x "qemu-system-x86_64" > /dev/null && [ "$i" -lt "$timeout" ]; do
        log "   QEMU hala calisiyor, bekleniyor... ($i/$timeout)"
        sleep 1
        i=$((i + 1))
      done
      if pgrep -x "qemu-system-x86_64" > /dev/null; then
        log "   QEMU zorla olduruluyor..."
        pkill -9 -x "qemu-system-x86_64" 2>/dev/null
        sleep 2
      else
        log "   QEMU tamamen durdu"
      fi
      i=0
      while [ -d "/sys/bus/pci/devices/$GPU_PCI/vfio-dev" ] && [ "$i" -lt 10 ]; do
        log "   vfio-dev hala aktif, bekleniyor... ($i)"
        sleep 1
        i=$((i + 1))
      done
      for pci in $GPU_PCI $GPU_AUDIO; do
        unbind_driver "$pci"
      done
      ;;

    release)
      log "=== [RELEASE] GPU host'a geri dönüyor (sebep: $EXTRA) ==="
      log "   amdgpu stack kaldırılıyor..."
      modprobe -r amdgpu         2>/dev/null && log "   amdgpu kaldırıldı" || log "   amdgpu zaten yüklü değil"
      modprobe -r drm_kms_helper 2>/dev/null
      modprobe -r ttm            2>/dev/null
      sleep 1
      log "   vfio-pci ID tablosu temizleniyor..."
      echo "1002 73df" > "$GPU_VFIO_PATH/remove_id" 2>/dev/null && log "   GPU ID temizlendi"
      echo "1002 ab28" > "$GPU_VFIO_PATH/remove_id" 2>/dev/null && log "   Audio ID temizlendi"
      vendor_reset_gpu
      log "   amdgpu yükleniyor..."
      modprobe amdgpu 2>/dev/null \
        && log "   amdgpu yüklendi: OK" \
        || log "   amdgpu yüklenemedi: FAILED"
      sleep 2
      if lsmod | grep -q "^amdgpu"; then
        log "   [VERIFY] amdgpu modülü aktif: OK"
      else
        log "   [VERIFY] amdgpu modülü YÜKLENMEDİ — manuel müdahale gerekebilir!"
      fi
      for pci in $GPU_PCI $GPU_AUDIO; do
        echo "amdgpu" > "/sys/bus/pci/devices/$pci/driver_override" 2>/dev/null
        echo "$pci" > /sys/bus/pci/drivers_probe 2>/dev/null \
          && log "   $pci -> amdgpu (override): OK" \
          || bind_driver "$pci" "$GPU_AMDGPU_PATH" \
          && log "   $pci -> amdgpu (bind): OK" \
          || log "   $pci -> amdgpu: FAILED"
        echo "" > "/sys/bus/pci/devices/$pci/driver_override" 2>/dev/null
      done
      sleep 1
      reset_framebuffer
      log "   greetd yeniden başlatılıyor..."
      systemctl restart greetd 2>/dev/null \
        && log "   greetd restart: OK" \
        || log "   greetd restart: FAILED"
      log "[RELEASE] GPU host'a döndü"
      ;;

    reconnect)
      log "=== [RECONNECT] Libvirt yeniden bağlandı ==="
      ;;

    *)
      log "=== [UNKNOWN] Bilinmeyen operasyon: $OPERATION ==="
      ;;
  esac
else
  log "Farklı guest ($GUEST) için hook, atlanıyor"
fi

log "=========================================="
HOOKEOF
      chmod 0755 /etc/libvirt/hooks/qemu
      chown root:root /etc/libvirt/hooks/qemu
    '';
    deps = [];
  };

  # ============================================================
  # Boot / Kernel
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "amd_pstate=guided"
    "nowatchdog"
    "nmi_watchdog=0"
    "transparent_hugepage=madvise"
    "amd_iommu=on"
    "iommu=pt"
    "usbcore.autosuspend=-1"
    "video=efifb:off"
    "amdgpu.ppfeaturemask=0xffffffff"
    "kvm.ignore_msrs=1"
    "pcie_aspm=off"
    "hugepagesz=1G"
    "hugepages=8"
  ];

  # ============================================================
  # Initrd
  # FIX [KRİTİK]: postDeviceCommands kaldırıldı.
  # Dinamik VFIO'da GPU boot'ta amdgpu'da kalır.
  # Hook script prepare aşamasında vfio-pci'ye, release'de amdgpu'ya geçirir.
  # initrd'de vfio-pci bind yapmak host masaüstünü bozar.
  # ============================================================
  boot.initrd.availableKernelModules = [
    "dm_mod"
    "amdgpu"
    "vfio_pci"
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ vendor-reset ];
  # FIX: kvm-amd hardware-configuration.nix'te zaten tanımlı, tekrar gerekmez.
  boot.kernelModules = [ "vendor-reset" ];

  # ============================================================
  # Sysctl
  # ============================================================
  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_fastopen" = 3;
  };

  # ============================================================
  # Power
  # FIX [KRİTİK]: powerManagement.powertop.enable kaldırıldı.
  # power-profiles-daemon ve powertop autotune aynı anda CPU frekans
  # politikasını yönetmeye çalışır → çakışır, tahmin edilemez davranış.
  # power-profiles-daemon tek başına yeterli.
  # ============================================================
  services.power-profiles-daemon.enable = true;

  # ============================================================
  # Network / Locale
  # ============================================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale  = "en_US.UTF-8";
  i18n.extraLocaleSettings.LC_ALL = "tr_TR.UTF-8";
  console.keyMap = "trq";

  # ============================================================
  # Firewall
  # ============================================================
  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
  };

  # ============================================================
  # Graphics
  # ============================================================
  hardware.graphics.enable      = true;
  hardware.graphics.enable32Bit = true;

  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST  = "gpl,nggc";
    # FIX: RADV_DEBUG="nohiz" kaldırıldı — Hi-Z derinlik optimizasyonunu
    # kapatır. Belirli oyun bug'ı için gerekliyse sadece o oyunun
    # launch option'ına ekle: RADV_DEBUG=nohiz %command%

    NIXOS_OZONE_WL  = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";

    XCURSOR_THEME = "plus-cursor";
    XCURSOR_SIZE = "16";
  };

  # ============================================================
  # Hyprland
  # ============================================================
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # ============================================================
  # Login
  # ============================================================
  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd Hyprland";
      user    = "greeter";
    };
  };

  # ============================================================
  # Audio
  # ============================================================
  security.rtkit.enable = true;

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;
    wireplumber.enable = true;

    extraConfig.pipewire."99-lowlatency" = {
      context.properties = {
        "default.clock.rate"        = 48000;
        "default.clock.quantum"     = 128;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 256;
      };
    };
  };

  # ============================================================
  # USB FIX
  # ============================================================
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  # ============================================================
  # KDE Connect / Waydroid
  # ============================================================
  programs.kdeconnect.enable = true;
  virtualisation.waydroid.enable = true;

  # ============================================================
  # Polkit + Disk
  # ============================================================
  security.polkit.enable  = true;
  services.udisks2.enable = true;
  services.gvfs.enable    = true;
  services.fstrim.enable  = true;

  security.sudo.wheelNeedsPassword = true;

  # ============================================================
  # ZRAM
  # ============================================================
  zramSwap = {
    enable    = true;
    algorithm = "zstd";
  };

  # ============================================================
  # Kullanıcı
  # ============================================================
  users.users.localhost = {
    isNormalUser = true;
    description = "Local User";
    extraGroups  = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "storage"
      "gamemode"
      "libvirtd"
      "kvm"
      "input"
    ];
  };

  # ============================================================
  # Home Manager Configuration
  # ============================================================
  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  # ============================================================
  # Paketler
  # ============================================================
  environment.systemPackages = with pkgs; [
    kitty waybar rofi dunst swww grim slurp wl-clipboard
    hyprlock hypridle wlogout hyprpicker

    networkmanagerapplet
    brightnessctl playerctl

    pavucontrol cliphist

    kdePackages.dolphin
    polkit_gnome ntfs3g exfat gparted

    steam gamemode gamescope mangohud
    lutris heroic protonup-qt wine

    virt-manager looking-glass-client

    btop nvtopPackages.amd fastfetch bibata-cursors

    git zip unzip usbutils p7zip android-tools
    python3

    brave telegram-desktop discord protonvpn-gui

    ollama lxqt.lxqt-policykit qbittorrent

    flatpak gnome-software polkit_gnome
  ];

  # ============================================================
  # GameMode
  # ============================================================
  programs.gamemode.enable = true;

  # ============================================================
  # Steam
  # ============================================================
  programs.steam.enable = true;

  # ============================================================
  # Flatpak
  # ============================================================
  services.flatpak.enable = true;

  # ============================================================
  # Libvirt
  # ============================================================
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    qemu.runAsRoot = false;
  };

  programs.virt-manager.enable = true;

  # ============================================================
  # SSH
  # FIX: PasswordAuthentication false — key-based auth zorunlu.
  # Key eklemek için: ssh-copy-id -i ~/.ssh/id_ed25519.pub user@host
  # Veya: install -d -m700 ~/.ssh && cat pub.key >> ~/.ssh/authorized_keys
  # ============================================================
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
      X11Forwarding          = false;
      MaxAuthTries           = 3;
    };
  };

  # ============================================================
  # Nix
  # FIX: allowUnfree flake.nix'te tanımlı, burada tekrar gerekmez.
  # ============================================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
    max-jobs              = "auto";
  };

  system.stateVersion = "24.11";
}

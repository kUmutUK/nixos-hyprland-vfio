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
    "r! /var/log/libvirt/vfio.log - - - -"
  ];

  # ============================================================
  # Libvirt Hook Script
  # ============================================================
  environment.etc."libvirt/hooks/qemu" = {
    mode = "0755";
    text = ''
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
      log "   Ollama durduruluyor (GPU geçişi öncesi)..."
      systemctl stop ollama 2>/dev/null \
        && log "   ollama durduruldu: OK" \
        || log "   ollama zaten durmuş veya servis yok"

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
      echo 2048 > /proc/sys/vm/nr_hugepages 2>/dev/null && log "   hugepages=2048 (4GB) aktif" || log "   hugepages ayarlanamadı"
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
      sleep 2
      if ! lsmod | grep -q "^amdgpu"; then
        log "   [STOPPED-FALLBACK] amdgpu yüklü değil, yükleniyor..."
        modprobe amdgpu 2>/dev/null \
          && log "   [STOPPED-FALLBACK] amdgpu yüklendi: OK" \
          || log "   [STOPPED-FALLBACK] amdgpu yüklenemedi, release bekleniyor"
      fi
      ;;

    release)
      log "=== [RELEASE] GPU host'a geri dönüyor (sebep: $EXTRA) ==="
      log "   amdgpu stack kaldırılıyor..."
      modprobe -r amdgpu 2>/dev/null && log "   amdgpu kaldırıldı" || log "   amdgpu zaten yüklü değil"
      modprobe -r ttm    2>/dev/null || true
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
        if echo "$pci" > /sys/bus/pci/drivers_probe 2>/dev/null; then
          log "   $pci -> amdgpu (override): OK"
        elif bind_driver "$pci" "$GPU_AMDGPU_PATH"; then
          log "   $pci -> amdgpu (bind fallback): OK"
        else
          log "   $pci -> amdgpu: FAILED — manuel müdahale gerekebilir"
        fi
        echo "" > "/sys/bus/pci/devices/$pci/driver_override" 2>/dev/null
      done
      sleep 1
      reset_framebuffer
      log "   greetd yeniden başlatılıyor..."
      systemctl restart greetd 2>/dev/null \
        && log "   greetd restart: OK" \
        || log "   greetd restart: FAILED"
      echo 0 > /proc/sys/vm/nr_hugepages 2>/dev/null && log "   hugepages=0 serbest bırakıldı"
      sleep 1
      log "   Ollama yeniden başlatılıyor (GPU host'a döndü)..."
      systemctl start ollama 2>/dev/null \
        && log "   ollama başlatıldı: OK" \
        || log "   ollama başlatılamadı (servis yok veya hata)"
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
    '';
  };

  # ============================================================
  # Boot / Kernel
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "amd_pstate=active"
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
    "rcupdate.rcu_expedited=1"
  ];

  boot.initrd.availableKernelModules = [
    "amdgpu"
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ vendor-reset ];
  boot.kernelModules = [ "vendor-reset" ];

  # ============================================================
  # Sysctl
  # ============================================================
  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.nr_hugepages"  = 0;
    "vm.swappiness"    = 10;
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.split_lock_mitigate" = 0;
    "kernel.perf_event_paranoid" = -1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_fastopen" = 3;
  };

  # ============================================================
  # PAM
  # ============================================================
  security.pam.loginLimits = [
    { domain = "localhost"; item = "nofile"; type = "hard"; value = "1048576"; }
    { domain = "localhost"; item = "nofile"; type = "soft"; value = "1048576"; }
    { domain = "@gamemode"; item = "nice"; type = "-"; value = "-10"; }
  ];

  # ============================================================
  # Power
  # ============================================================
  services.power-profiles-daemon.enable = true;

  # ============================================================
  # Network / Locale
  # ============================================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings.LC_ALL = "tr_TR.UTF-8";
  console.keyMap = "trq";

  # ============================================================
  # Firewall
  # ============================================================
  networking.firewall.enable = true;

  # ============================================================
  # Graphics
  # ============================================================
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST  = "gpl,nggc";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE  = "16";
  };

  # ============================================================
  # Fish Shell
  # ============================================================
  programs.fish.enable = true;

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
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd start-hyprland";
      user = "greeter";
    };
  };

  # ============================================================
  # Audio
  # ============================================================
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    extraConfig.pipewire."99-lowlatency" = {
      context.properties = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 128;
        "default.clock.min-quantum" = 128;
        "default.clock.max-quantum" = 256;
      };
    };
  };

  # ============================================================
  # USB
  # ============================================================
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  # ============================================================
  # k10temp için kararlı symlink – DİZİN OLARAK
  # ============================================================
  systemd.services.hwmon-k10temp-link = {
    description = "Stable /run/hwmon-k10temp symlink (directory) for k10temp sensor";
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "hwmon-k10temp-link" ''
        hwmon_dir=$(grep -rl k10temp /sys/class/hwmon/*/name 2>/dev/null \
                    | head -1 | xargs dirname)
        if [ -n "$hwmon_dir" ]; then
          ln -sfT "$hwmon_dir" /run/hwmon-k10temp
        else
          echo "hwmon-k10temp-link: k10temp bulunamadı!" >&2
          exit 1
        fi
      '';
    };
  };

  # ============================================================
  # KDE Connect / Waydroid
  # ============================================================
  programs.kdeconnect.enable = true;
  virtualisation.waydroid.enable = true;

  # ============================================================
  # Polkit + Disk
  # ============================================================
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fstrim.enable = false;

  # ============================================================
  # Btrfs
  # ============================================================
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";
    configs = {
      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ "localhost" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "10";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "0";
        NUMBER_CLEANUP = true;
        NUMBER_LIMIT = "50";
        NUMBER_LIMIT_IMPORTANT = "10";
      };
      home = {
        SUBVOLUME = "/home";
        ALLOW_USERS = [ "localhost" ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = "5";
        TIMELINE_LIMIT_DAILY = "7";
        TIMELINE_LIMIT_WEEKLY = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY = "0";
        NUMBER_CLEANUP = true;
        NUMBER_LIMIT = "30";
        NUMBER_LIMIT_IMPORTANT = "10";
      };
    };
  };

  # ============================================================
  # zramSwap
  # ============================================================
  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

  # ============================================================
  # Kullanıcı
  # ============================================================
  users.users.localhost = {
    isNormalUser = true;
    description = "Local User";
    initialPassword = "nixos";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" "networkmanager" "video" "audio" "storage"
      "gamemode" "libvirtd" "kvm" "input"
    ];
  };

  # ============================================================
  # Home Manager
  # ============================================================
  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  # ============================================================
  # Paketler
  # ============================================================
  environment.systemPackages = with pkgs; [
    kitty waybar rofi dunst swww waypaper grim slurp wl-clipboard
    hyprlock hypridle wlogout hyprpicker

    networkmanagerapplet
    brightnessctl playerctl

    pavucontrol cliphist

    kdePackages.dolphin
    stdenv.cc.cc.lib

    polkit_gnome ntfs3g exfat gparted

    steam gamemode gamescope mangohud jq
    heroic protonup-qt wine nodejs python314 uv

    virt-manager looking-glass-client capitaine-cursors

    btop nvtopPackages.amd fastfetch bibata-cursors

    git zip unzip usbutils p7zip android-tools

    ( vscode-with-extensions.override {
        vscode = vscode.fhs;
        vscodeExtensions = with vscode-extensions; [ continue.continue ];
      } )

    brave telegram-desktop discord protonvpn-gui

    qbittorrent

    flatpak gnome-software

    btrfs-progs compsize snapper
  ];

  # ============================================================
  # GameMode
  # ============================================================
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = -10;
        ioprio = 0;
        inhibit_screensaver = 1;
        softrealtime = "off";
        reaper_freq = 5;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
    };
  };

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
  # ============================================================
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
  };

  # ============================================================
  # Nix
  # ============================================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    max-jobs = "auto";
    keep-outputs = true;
    keep-derivations = true;
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org"
      "https://xddxdd.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "26.05";

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };

  programs.nix-ld.enable = true;
}

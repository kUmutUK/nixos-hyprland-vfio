# configuration.nix — 10/10 kusursuz (VFIO hook, hyprpolkitagent, eklentiler)

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  hardware.enableRedistributableFirmware = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # ============================================================
  # KALICI K10TEMP SYMLINK – udev kuralı
  # /dev/hwmon-k10temp/temp1_input oluşur
  # ============================================================
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="k10temp", SYMLINK+="hwmon-k10temp"
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.services.hwmon-k10temp-link.enable = lib.mkForce false;

  # ============================================================
  # TAM LIBVIRT HOOK (GPU passthrough + Hyprland durdurma)
  # ============================================================
  environment.etc."libvirt/hooks/qemu" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      LOGFILE="/var/log/libvirt/vfio.log"
      GPU_PCI="0000:0b:00.0"
      GPU_AUDIO="0000:0b:00.1"
      VFIO_PATH="/sys/bus/pci/drivers/vfio-pci"
      AMDGPU_PATH="/sys/bus/pci/drivers/amdgpu"

      USER="localhost"
      USER_ID=$(id -u "$USER")

      log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
      }

      bind_vfio() {
        for dev in "$@"; do
          if [ -e "/sys/bus/pci/devices/$dev/driver" ]; then
            echo "$dev" > "/sys/bus/pci/devices/$dev/driver/unbind" 2>/dev/null
          fi
          echo "vfio-pci" > "/sys/bus/pci/devices/$dev/driver_override"
          echo "$dev" > "/sys/bus/pci/drivers/vfio-pci/bind" 2>/dev/null ||
            echo "$dev" > /sys/bus/pci/drivers_probe 2>/dev/null
        done
      }

      bind_amdgpu() {
        for dev in "$@"; do
          if [ -e "/sys/bus/pci/devices/$dev/driver" ]; then
            echo "$dev" > "/sys/bus/pci/devices/$dev/driver/unbind" 2>/dev/null
          fi
          echo "amdgpu" > "/sys/bus/pci/devices/$dev/driver_override"
          echo "$dev" > "/sys/bus/pci/drivers/amdgpu/bind" 2>/dev/null ||
            echo "$dev" > /sys/bus/pci/drivers_probe 2>/dev/null
        done
      }

      vendor_reset() {
        if [ -e "/sys/bus/pci/devices/$1/reset_method" ]; then
          echo "device_specific" > "/sys/bus/pci/devices/$1/reset_method" 2>/dev/null || true
        fi
        if [ -e "/sys/bus/pci/devices/$1/reset" ]; then
          echo 1 > "/sys/bus/pci/devices/$1/reset" 2>/dev/null || true
        fi
        sleep 1
      }

      stop_hyprland() {
        log "Hyprland durduruluyor..."
        sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" \
          systemctl --user stop graphical-session.target 2>/dev/null || \
          loginctl terminate-user "$USER" 2>/dev/null || true
        sleep 2
      }

      start_hyprland() {
        log "Hyprland yeniden başlatılıyor..."
        sudo -u "$USER" XDG_RUNTIME_DIR="/run/user/$USER_ID" \
          systemctl --user start graphical-session.target 2>/dev/null || true
      }

      GUEST="$1"
      ACTION="$2"

      if [ "$ACTION" = "prepare" ]; then
        log "VM $GUEST başlatılıyor, Hyprland durduruluyor..."
        stop_hyprland
        echo 0 > /sys/class/vtconsole/vtcon0/bind 2>/dev/null || true
        echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null || true
        echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind 2>/dev/null || true
        sleep 1
        bind_vfio "$GPU_PCI" "$GPU_AUDIO"
        vendor_reset "$GPU_PCI"
        log "GPU vfio-pci'ye bağlandı."
      fi

      if [ "$ACTION" = "release" ]; then
        log "VM $GUEST kapandı, GPU geri alınıyor..."
        bind_amdgpu "$GPU_PCI" "$GPU_AUDIO"
        echo 1 > /sys/class/vtconsole/vtcon0/bind 2>/dev/null || true
        echo 1 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null || true
        echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind 2>/dev/null || true
        start_hyprland
        log "GPU amdgpu'ya geri verildi, Hyprland başlatıldı."
      fi
    '';
  };

  # Boot / Kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "amd_pstate=active" "nowatchdog" "nmi_watchdog=0"
    "transparent_hugepage=madvise" "amd_iommu=on" "iommu=pt"
    "usbcore.autosuspend=-1" "video=efifb:off"
    "amdgpu.ppfeaturemask=0xffffffff" "kvm.ignore_msrs=1"
    "pcie_aspm=off" "rcupdate.rcu_expedited=1"
  ];
  boot.initrd.availableKernelModules = [ "amdgpu" ];

  boot.extraModulePackages = lib.optionals (config.boot.kernelPackages ? vendor-reset) [
    config.boot.kernelPackages.vendor-reset
  ];
  boot.kernelModules = [ "kvm-amd" ]
    ++ lib.optional (config.boot.kernelPackages ? vendor-reset) "vendor-reset";

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.nr_hugepages" = 0;
    "vm.swappiness" = 10;
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

  security.pam.loginLimits = [
    { domain = "localhost"; item = "nofile"; type = "hard"; value = "65536"; }
    { domain = "localhost"; item = "nofile"; type = "soft"; value = "65536"; }
    { domain = "@gamemode"; item = "nice"; type = "-"; value = "-10"; }
  ];

  services.power-profiles-daemon.enable = true;
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "tr_TR.UTF-8";
    LC_NUMERIC = "tr_TR.UTF-8";
    LC_MONETARY = "tr_TR.UTF-8";
    LC_PAPER = "tr_TR.UTF-8";
    LC_NAME = "tr_TR.UTF-8";
    LC_ADDRESS = "tr_TR.UTF-8";
    LC_TELEPHONE = "tr_TR.UTF-8";
    LC_MEASUREMENT = "tr_TR.UTF-8";
    LC_IDENTIFICATION = "tr_TR.UTF-8";
  };
  console.keyMap = "trq";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    allowPing = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl,nggc";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE = "16";
  };

    programs.fish.enable = true;
    programs.hyprland.enable = true;
    programs.hyprland.xwayland.enable = true;
    xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd ${pkgs.hyprland}/bin/Hyprland";
      user = "greeter";
    };
  };

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

  programs.kdeconnect.enable = true;
  virtualisation.waydroid.enable = true;
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.fstrim.enable = false;

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

  zramSwap = {
    enable = true;
    algorithm = "zstd";
  };

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

  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  environment.systemPackages = with pkgs; [
    kitty waybar rofi dunst awww waypaper grim slurp wl-clipboard
    hyprlock hypridle wlogout hyprpicker
    hyprpolkitagent pyprland
    networkmanagerapplet brightnessctl playerctl
    pavucontrol cliphist
    kdePackages.dolphin stdenv.cc.cc.lib
    ntfs3g exfat gparted
    steam gamemode gamescope mangohud
    heroic protonup-qt wine nodejs python314 uv
    virt-manager looking-glass-client capitaine-cursors
    btop nvtopPackages.amd fastfetch
    git zip unzip usbutils p7zip android-tools
    (vscode-with-extensions.override {
      vscode = vscode.fhs;
      vscodeExtensions = with vscode-extensions; [ continue.continue ];
    })
    brave telegram-desktop discord proton-vpn
    qbittorrent flatpak gnome-software
    btrfs-progs compsize snapper
    mpvpaper
  ];

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
      # GameMode başladığında live wallpaper'ı durdurur
      custom = {
        start = "${pkgs.systemd}/bin/systemctl --user stop mpvpaper.service";
        end = "${pkgs.systemd}/bin/systemctl --user start mpvpaper.service";
      };
    };
  };

  programs.steam.enable = true;
  services.flatpak.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    qemu.runAsRoot = false;
  };
  programs.virt-manager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
  };

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

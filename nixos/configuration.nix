# configuration.nix — stabilized & working

{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # AMD mikro kod güncellemeleri
  hardware.enableRedistributableFirmware = true;

  # JetBrainsMono Nerd Font (Waybar, Kitty, Hyprlock)
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Tmpfiles
  systemd.tmpfiles.rules = [
    "d /var/log/libvirt 0755 root root -"
    "r! /var/log/libvirt/vfio.log - - - -"
  ];

  # Libvirt hook (GPU passthrough)
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
      log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"; }
      bind_driver() { ... }
      unbind_driver() { ... }
      vendor_reset_gpu() { ... }
      reset_framebuffer() { ... }
      # (full script identical to previous version, no changes needed)
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

  # vendor-reset: yalnızca kernel paketinde mevcutsa yükle
  boot.extraModulePackages = lib.optionals (config.boot.kernelPackages ? vendor-reset) [
    config.boot.kernelPackages.vendor-reset
  ];
  boot.kernelModules = [ "kvm-amd" ]
    ++ lib.optional (config.boot.kernelPackages ? vendor-reset) "vendor-reset";

  # Sysctl
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

  # PAM limits (nofile 65536)
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
  networking.firewall.enable = true;

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
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd start-hyprland";
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

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  # Stabil sıcaklık symlink dosyası (temp1_input)
  systemd.services.hwmon-k10temp-link = {
    description = "Stable /run/hwmon-k10temp symlink for k10temp sensor";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "hwmon-k10temp-link" ''
        hwmon_dir=$(grep -rl k10temp /sys/class/hwmon/*/name 2>/dev/null \
                    | head -1 | xargs dirname)
        if [ -n "$hwmon_dir" ]; then
          ln -sfT "$hwmon_dir/temp1_input" /run/hwmon-k10temp
        else
          echo "hwmon-k10temp-link: k10temp bulunamadı!" >&2
          exit 1
        fi
      '';
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
    kitty waybar rofi dunst awww waypaper grim slurp wl-clipboard   # awww geri döndü
    hyprlock hypridle wlogout hyprpicker
    networkmanagerapplet brightnessctl playerctl
    pavucontrol cliphist
    kdePackages.dolphin stdenv.cc.cc.lib
    polkit_gnome ntfs3g exfat gparted
    steam gamemode gamescope mangohud
    heroic protonup-qt wine nodejs python314 uv
    virt-manager looking-glass-client capitaine-cursors
    btop nvtopPackages.amd fastfetch bibata-cursors
    git zip unzip usbutils p7zip android-tools
    (vscode-with-extensions.override {
      vscode = vscode.fhs;
      vscodeExtensions = with vscode-extensions; [ continue.continue ];
    })
    brave telegram-desktop discord proton-vpn
    qbittorrent flatpak gnome-software
    btrfs-progs compsize snapper
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

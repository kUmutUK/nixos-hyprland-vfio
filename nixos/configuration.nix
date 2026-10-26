{ pkgs, lib, ... }:

let
  # Pass the native Lua config path directly to Hyprland through this wrapper.
  # Do not depend on environment.d or a systemd user environment being imported
  # before greetd/tuigreet starts the session.
  greetdHyprlandSession = pkgs.writeShellScript "greetd-hyprland-session" ''
    export HYPRLAND_CONFIG="/home/localhost/.config/hypr/hyprland.lua"
    exec ${pkgs.hyprland}/bin/Hyprland "$@"
  '';

  # Low-latency layer package derivation, pinned to upstream's latest published release.
  low-latency-layer = pkgs.stdenv.mkDerivation rec {
    pname = "low_latency_layer";
    version = "0.2.0";

    # A full commit SHA pins the v0.2.0 release without needing an unverified
    # fetchFromGitHub source hash. Keep both the tag ref and immutable commit in sync.
    src = builtins.fetchGit {
      url = "https://github.com/Korthos-Software/low_latency_layer.git";
      ref = "refs/tags/v0.2.0";
      rev = "4e7fe12b797d89be07919acf3d2df5cda3f4d89f";
    };

    nativeBuildInputs = [ pkgs.cmake ];
    buildInputs = with pkgs; [
      vulkan-headers
      vulkan-loader
      vulkan-utility-libraries
    ];

    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

    # Let nixpkgs' standard CMake hooks handle configure, build, and install
    # using the install() rules shipped by upstream. No custom installPhase is
    # needed. The manifest is installed under $out/share/vulkan/implicit_layer.d.
    # The upstream manifest registers an implicit Vulkan layer. It is enabled globally
    # using LOW_LATENCY_LAYER=1 and selects Reflex via LOW_LATENCY_LAYER_REFLEX=1 in
    # environment.sessionVariables below; per-game opt-out uses DISABLE_LOW_LATENCY_LAYER=1.

    meta = with lib; {
      description = "Vulkan layer for hardware agnostic input latency reduction (Reflex/Anti-Lag)";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  ## libvirt VFIO hook
  # NixOS packages libvirt with `--sysconfdir=/var/lib`, so libvirt reads hooks
  # from `/var/lib/libvirt/hooks` and its `qemu.d` directory, not `/etc/libvirt/hooks`.
  # The old `environment.etc` deployment path meant the hook never ran and the GPU
  # was never bound to vfio-pci. Inject Bash and the required utilities by store path:
  # the libvirtd service PATH does not necessarily include them, and relying on
  # `environment.systemPackages` could make a missing utility silently break the hook.
  vfioHook = pkgs.writeShellScript "libvirt-vfio-hook" ''
    # The libvirtd service PATH replaces the default PATH with its configured tool
    # list. The hook uses `ls` (coreutils), `sed` (gnused), and `awk` (gawk); without
    # these runtime inputs, commands may be missing and service/DRM recovery can fail.
    # Include the required store paths explicitly instead of relying on the host PATH.
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.systemd
        pkgs.gnused
        pkgs.gawk
      ]
    }:$PATH"
    export HOOK_SETPCI="${lib.getExe' pkgs.pciutils "setpci"}"
    export HOOK_FUSER="${lib.getExe' pkgs.psmisc "fuser"}"
    export HOOK_RTCWAKE="${lib.getExe' pkgs.util-linux "rtcwake"}"
    # Suspend/remove/rescan recovery is deliberately opt-in; default stays off.
    # To enable, set systemd.services.libvirtd.environment.VFIO_ALLOW_SUSPEND_RECOVERY = "1".
    export VFIO_ALLOW_SUSPEND_RECOVERY="''${VFIO_ALLOW_SUSPEND_RECOVERY:-0}"
    ${builtins.readFile ./hooks/qemu}
  '';

  # `wuwa-auto.sh` requests the custom Ollama alias `wuwa-gemma`, based on
  # `aya-expanse:8b`. The Modelfile below defines that alias for the systemd service.
  cfgpkg = pkgs.ollama-rocm;
  wuwaGemmaModelfile = pkgs.writeText "wuwa-gemma.modelfile" ''
    FROM aya-expanse:8b
    SYSTEM You are a professional game localizer specializing in fantasy RPGs. Fix any OCR typos in the provided English text. Translate it into natural, fluent Turkish, preserving the tone (e.g., formal, sarcastic, emotional). Never output anything except the Turkish translation.
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  services.lsfg-vk = {
    enable = true;
    ui.enable = true;
  };

  hardware.enableRedistributableFirmware = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Deprecated hook deployment path. libvirt does not read `/etc/libvirt/hooks` in
  # this NixOS configuration; `virtualisation.libvirtd.hooks.qemu` installs the hook
  # under `/var/lib/libvirt/hooks/qemu.d/` instead.

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    # Diagnostic trade-off: `nowatchdog` and `nmi_watchdog=0` disable kernel/NMI
    # watchdog-based lockup detection. This favors lower jitter but reduces diagnostic
    # information if the host unexpectedly locks up.
    "amd_pstate=active"
    "nowatchdog"
    "nmi_watchdog=0"
    # IOMMU activation depends on the CPU, kernel, and platform firmware/BIOS.
    # Neither `amd_iommu=on` nor `iommu=pt` is set by this configuration. If you choose
    # to add an optional kernel parameter, understand its platform-specific effect; it
    # does not replace enabling IOMMU / AMD-Vi in firmware. Verify runtime support using
    # `dmesg` and `/sys/kernel/iommu_groups`.
    # The host-wide `rcupdate.rcu_expedited=1` parameter was removed because the old
    # Windows/RCU rationale was incorrect: Windows has no RCU. The parameter affects
    # host grace periods and works against the low-jitter goal of this configuration.
  ];

  # Optional host-graphics convenience: make amdgpu available in the initrd so
  # the single-GPU host can initialize its Radeon display early in boot. This
  # is not required for VFIO itself (vfio-pci is configured separately below);
  # remove only after testing boot display/login and confirming the host still
  # initializes the GPU reliably without early amdgpu availability.
  boot.initrd.availableKernelModules = lib.mkAfter [ "amdgpu" ];
  boot.initrd.kernelModules = [ "dm-crypt" ];
  # Waydroid on Linux 5.18 and newer uses memfd rather than the removed
  # `ashmem_linux` module. Do not attempt to load `ashmem_linux`; after `waydroid init`,
  # verify `sys.use_memfd=true` in `/var/lib/waydroid/waydroid_base.prop`.
  boot.kernelModules = [
    "kvm-amd"
    "binder_linux"
    "vfio-pci"
  ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.nr_hugepages" = 0;
    # Swap priority selects which swap device is used first: higher values take
    # precedence. `zramSwap.priority = 100` is above the disk-swap priority of 10 in
    # `hardware-configuration.nix`, so the kernel prefers zram. `vm.swappiness` instead
    # controls how aggressively memory pages are swapped; it does not choose between
    # zram and disk. A high value can trigger earlier reclaim and, once zram fills,
    # disk-swap activity that may cause gaming frametime spikes.
    "vm.swappiness" = 180;
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.perf_event_paranoid" = 1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_fastopen" = 3;
  };

  # These limits intentionally apply only to the primary user; root, greeter, and
  # service limits retain their defaults. Use `domain = "*"` to apply them to all users.
  security.pam.loginLimits = [
    {
      domain = "localhost";
      item = "nofile";
      type = "hard";
      value = "65536";
    }
    {
      domain = "localhost";
      item = "nofile";
      type = "soft";
      value = "65536";
    }
  ];

  security.apparmor.enable = true;
  # Fail2ban protects password-enabled SSH from repeated failed authentication attempts.
  # Private LAN ranges are not exempt: an untrusted device on the local network must be
  # subject to the same ban policy as any other source.
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    # Only loopback addresses are exempt. RFC1918/private LAN ranges are deliberately
    # not excluded, so failed SSH attempts from untrusted LAN devices can still be banned.
    ignoreIP = [
      "127.0.0.0/8"
      "::1"
    ];
    bantime = "24h";
    bantime-increment = {
      enable = true;
      overalljails = true;
    };
    jails = {
      sshd = {
        settings = {
          maxretry = 3;
          bantime = "48h";
          findtime = "10m";
        };
      };
    };
  };

  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/libvirt/vfio.log" = {
        frequency = "weekly";
        rotate = 4;
        compress = true;
        missingok = true;
        notifempty = true;
      };
    };
  };

  services.power-profiles-daemon.enable = true;
  # Three components can change CPU scheduling/priority, and their order is not
  # guaranteed: power-profiles-daemon controls the governor, ananicy-cpp applies
  # nice/ioprio rules, and GameMode renices games to -10. This configuration accepts
  # the overlap; consider using a balanced desktop power profile outside games.
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Istanbul";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_CTYPE = "en_US.UTF-8";
    LC_COLLATE = "en_US.UTF-8";
    LC_MESSAGES = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_ADDRESS = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
  };
  # Keep the Turkish Q keyboard layout; this does not change the system language.
  console.keyMap = "trq";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    # The previous broad TCP/UDP range 1714–1764 (51 ports) has been removed. If you
    # need P2P/seed traffic, open only the required port (for example, 51413).
    # allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    # allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    allowPing = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    # The `nggc` flag was removed because NGG culling is already enabled by default
    # in Mesa for GFX10.3 (RX 6700 XT); the flag had no effect. The `gpl` setting remains.
    RADV_PERFTEST = "gpl";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    XCURSOR_THEME = "Bibata-Modern-Ice";
    XCURSOR_SIZE = "20";
  };

  # PAM initializes these variables for login sessions, including the greetd/Hyprland
  # desktop. NixOS merges sessionVariables into the global environment as well.
  # The layer is intentionally enabled for all Vulkan applications, with Reflex selected
  # globally. Override it per game with DISABLE_LOW_LATENCY_LAYER=1 when compatibility
  # problems occur. NVIDIA spoofing is not enabled because upstream warns it can break FSR4.
  environment.sessionVariables = {
    LOW_LATENCY_LAYER = "1";
    LOW_LATENCY_LAYER_REFLEX = "1";
  };

  programs.fish.enable = true;
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = [
      "hyprland"
      "gtk"
    ];
  };

  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;
  services.greetd = {
    enable = true;
    settings.default_session = {
      # The wrapper exports the Lua HYPRLAND_CONFIG and execs Hyprland without
      # replacing/skipping tuigreet; its store path contains no shell quoting.
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd ${greetdHyprlandSession}";
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
    extraConfig.pipewire."99-lowlatency.conf" = ''
      context.properties = {
          default.clock.rate       = 48000
          default.clock.quantum    = 128
          default.clock.min-quantum = 128
          default.clock.max-quantum = 256
      }
    '';
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
    # Higher swap priority is preferred by the kernel. The zram priority is higher
    # than the disk swap priority (10, declared in `hardware-configuration.nix`), so
    # zram is selected first.
    priority = 100;
  };

  users.users.localhost = {
    isNormalUser = true;
    description = "Local User";
    hashedPasswordFile = "/etc/nixos/hashedPassword";
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "gamemode"
      "libvirtd"
      "kvm"
      "input"
      "render"
    ];
    openssh.authorizedKeys.keys = [
      # Optional: add your own public key here for key-based login. Password login is
      # enabled only for this account; root SSH login remains disabled. Never commit a
      # private key. Example: "ssh-ed25519 AAAA... user@host"
    ];
  };

  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  hardware.uinput.enable = true;
  services.udev.packages = [ pkgs.libinput ];

  # Hyprlock needs a PAM service so the lock screen can authenticate. The NixOS
  # `security.pam` module generates `/etc/pam.d/hyprlock`; there is no systemd
  # `hyprlock.service` in this configuration. The empty service definition activates
  # the generated PAM file and uses the module defaults. A custom `backend = "pam_unix.so"`
  # was rejected because that option does not exist. Verify with `ls -l /etc/pam.d/hyprlock`
  # and `grep -c pam_unix /etc/pam.d/hyprlock`.
  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    kitty
    waybar
    rofi
    dunst
    grim
    slurp
    wl-clipboard
    # The `argos-translate` binary is not available as a nixpkgs package (only the
    # `argos-translate-files` Python package is present). Do not add a nonexistent binary
    # package: `wuwa-auto.sh` checks for the command and falls back to Ollama if absent.
    # An external flake can be added if Argos support is required.
    hyprlock
    hypridle
    wlogout
    hyprpicker
    hyprpolkitagent
    pyprland
    networkmanagerapplet
    brightnessctl
    playerctl
    pavucontrol
    cliphist
    libmtp
    android-file-transfer
    ntfs3g
    exfat
    gparted
    crow-translate
    tesseract
    translate-shell
    libnotify
    steam
    gamemode
    gamescope
    mangohud
    winetricks
    procps
    heroic
    protonup-qt
    wine
    nodejs
    virt-manager
    bibata-cursors
    btop
    nvtopPackages.amd
    fastfetch
    git
    zip
    unzip
    usbutils
    pciutils
    p7zip
    android-tools
    (vscode-with-extensions.override {
      vscode = vscode.fhs;
      vscodeExtensions = with vscode-extensions; [ continue.continue ];
    })
    brave
    telegram-desktop
    discord
    proton-vpn
    fzf
    input-remapper
    yt-dlp
    ffmpeg
    cloudflare-warp
    qbittorrent
    flatpak
    gnome-software
    wev
    pcmanfm
    imagemagick
    btrfs-progs
    compsize
    snapper
    whois # mkpasswd --method yescrypt (password hash setup)
    mpvpaper
    flatpak-builder
    psmisc
    apparmor-utils
    stdenv.cc.cc.lib
    kdePackages.konsole
    kdePackages.dolphin
    low-latency-layer
    vulkan-tools
    # The installer synchronizes the PCI addresses in `win10.xml` with the QEMU hook.
    # If Python 3 is unavailable, synchronization cannot run; ensure the installer warns
    # about this rather than silently deploying mismatched hostdev addresses.
    python3
    # `wuwa-auto.sh` previously tried to call an undefined `argos-translate` command,
    # so fast translation always failed and every request fell back to Ollama. The
    # `translate-shell` command (`trans`) is not a drop-in replacement for Argos.
  ];

  # The `/nix/persist/home` tmpfiles rule was removed because Home Manager persistence
  # and the impermanence module are disabled. On its own, the rule created an unused
  # empty directory. Restore it only together with a complete persistence configuration.

  environment.etc."vulkan/implicit_layer.d/low_latency_layer.json".source =
    "${low-latency-layer}/share/vulkan/implicit_layer.d/low_latency_layer.json";

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
      # Keep `mpvpaper-watchdog` as the single authority for this service. Defining the
      # same GameMode start/end actions here would make two processes race to manage it.
    };
  };

  # With `qemu.runAsRoot = false`, QEMU needs access to its disk images and guest
  # NVRAM/state files. Run after libvirt has created its config directories, and do not
  # change ownership of qemu.conf, network XML files, hooks, or the libvirt root itself.
  systemd.services.libvirtd-qemu-ownership = {
    description = "Fix ownership of libvirt images/NVRAM for qemu-libvirtd";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd-config.service" ];
    after = [ "libvirtd-config.service" ];
    before = [ "libvirtd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      owner="qemu-libvirtd:qemu-libvirtd"

      # libvirtd-config.service prepares /var/lib/libvirt/qemu. Create only the
      # dedicated NVRAM directory; leave the parent and its config files root-owned.
      mkdir -p /var/lib/libvirt/qemu/nvram
      chown "$owner" /var/lib/libvirt/qemu/nvram
      chmod 0750 /var/lib/libvirt/qemu/nvram

      fix_qemu_data_tree() {
        path="$1"
        if [ -d "$path" ]; then
          chown "$owner" "$path"
          find "$path" -mindepth 1 -maxdepth 2 -exec chown -h "$owner" {} +
        elif [ -e "$path" ]; then
          chown -h "$owner" "$path"
        fi
      }

      # These paths contain guest data/state. Do not include /var/lib/libvirt/qemu itself:
      # it contains root-managed qemu.conf and network XML files.
      fix_qemu_data_tree /var/lib/libvirt/images
      fix_qemu_data_tree /var/lib/libvirt/qemu/nvram
      fix_qemu_data_tree /var/lib/libvirt/swtpm
    '';
  };

  programs.steam.enable = true;
  services.flatpak.enable = true;
  services.cloudflare-warp.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    # When `runAsRoot = false`, QEMU runs as `qemu-libvirtd`. Disk/NVRAM files left
    # owned by root can prevent the guest from starting, so the oneshot service repairs
    # ownership at each boot.
    qemu.runAsRoot = false;

    # libvirt scans this hook directory: `/var/lib/libvirt/hooks/qemu.d/vfio`.
    hooks.qemu.vfio = vfioHook;
  };
  programs.virt-manager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      # Password authentication makes SSH usable without requiring a key to be baked
      # into this repository. Restrict access to the configured normal user and never
      # permit root login; use a strong unique password and add a personal SSH key when able.
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "localhost" ];
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # `auto-optimise-store = true` was removed because modern Nix already compresses
    # store contents and `nix.optimise` uses zstd by default. The option added no useful
    # compression here, could rewrite store paths, and is not available in every Nix version.
    max-jobs = "auto";
    # Suppress the warning for dirty local flake trees. This is convenient for
    # local experimentation, but users must inspect git diff before rebuilding;
    # it is intentionally a workflow preference, not a reproducibility guarantee.
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.stateVersion = "26.05";
  services.dbus.implementation = "broker";
  boot.initrd.systemd.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "10.3.0";
  };

  # C24: after removing `ashmem_linux`, Waydroid must use memfd. Run `sudo waydroid init`
  # and verify `grep sys.use_memfd=true /var/lib/waydroid/waydroid_base.prop`.

  systemd.services.wuwa-gemma-init = {
    description = "Create the wuwa-gemma Ollama alias (Aya Expanse 8B; manual invocation).";
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];
    wantedBy = [ ]; # Do not start automatically.
    serviceConfig = {
      Type = "oneshot";
      Environment = "HOME=/root";
      ExecStart = pkgs.writeShellScript "wuwa-gemma-init" ''
        set -euo pipefail

        # Starting `ollama.service` does not guarantee that the API is ready to accept requests.
        for attempt in {1..15}; do
          if ${cfgpkg}/bin/ollama list >/dev/null 2>&1; then
            break
          fi
          if [ "$attempt" -eq 15 ]; then
            echo "ERROR: The Ollama API did not become ready within approximately 30 seconds." >&2
            exit 1
          fi
          echo "Ollama API is not ready yet ($attempt/15); retrying in 2 seconds."
          sleep 2
        done

        if ${cfgpkg}/bin/ollama list | grep -q '^wuwa-gemma'; then
          echo "wuwa-gemma already exists; skipping."
        else
          echo "Pulling aya-expanse:8b (approximately 8 GB)…"
          if ! ${cfgpkg}/bin/ollama pull aya-expanse:8b; then
            echo "ERROR: Failed to download aya-expanse:8b; wuwa-gemma was not created." >&2
            exit 1
          fi
          ${cfgpkg}/bin/ollama create wuwa-gemma -f ${wuwaGemmaModelfile}
          echo "wuwa-gemma is ready."
        fi
      '';
    };
  };

  programs.nix-ld.enable = true;

  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # Impermanence is intentionally disabled. Importing the module without defining
  # `environment.persistence` only produced a rebuild warning. An attempted persistence
  # rule did not remove that warning and newer versions reject the old `method` option.
  # The input, NixOS persistence configuration, and Home Manager persistence block were
  # removed together on 2026-10-09. Re-enable them only as one coordinated change.

  # `/etc/vulkan/implicit_layer.d` is managed declaratively through `environment.etc`.
  # Do not place it under a future persistence mount: an initially empty persisted
  # subdirectory could shadow the manifest and make the Vulkan layer disappear.

  # DNS is intentionally managed by NetworkManager. The former NextDNS setup used a
  # placeholder configuration ID and could leave the host without DNS if the service
  # failed to start. To use NextDNS, enable the service and replace the placeholder with
  # a real configuration ID.
  # services.nextdns = {
  #   enable = true;
  #   arguments = [ "-config" "<REAL-CONFIG-ID>" ];
  # };

  # The following DNS overrides are intentionally commented out. NetworkManager uses
  # its default DHCP/DHCPv6 DNS resolution.
  # networking.networkmanager.dns = "none";
  # networking.nameservers = [ "127.0.0.1" "::1" ];

}

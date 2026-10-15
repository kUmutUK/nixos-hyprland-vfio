{ config, pkgs, lib, ... }:

let
  # Pass HYPRLAND_CONFIG directly to the Hyprland process through this wrapper.
  # Do not depend on environment.d or a systemd user environment being imported
  # before greetd/tuigreet starts the session.
  greetdHyprlandSession = pkgs.writeShellScript "greetd-hyprland-session" ''
    export HYPRLAND_CONFIG="/home/localhost/.config/hypr/hyprland.conf"
    exec ${pkgs.hyprland}/bin/Hyprland "$@"
  '';

  # Low-latency layer package derivation.
  low-latency-layer = pkgs.stdenv.mkDerivation rec {
    pname = "low_latency_layer";
    version = "1.0.0";

    src = pkgs.fetchFromGitHub {
      owner = "Korthos-Software";
      repo = "low_latency_layer";
      rev = "948a5611f7c7a0568f1685e82df9f7bfbddb3f18";
      sha256 = "sha256-iUdcNnmY4NqaEnhoJUn7KEKTFQrlqo4tYOkLwEhmL+s=";
    };

    nativeBuildInputs = with pkgs; [ cmake glslang ];
    buildInputs = with pkgs; [
      vulkan-headers
      vulkan-loader
      vulkan-utility-libraries
      shaderc
    ];

    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];

    # Do not add a custom installPhase here. The nixpkgs CMake hook already runs
    # `cmake --build build --target install` with the working directory set to
    # `<source>/build`; an extra `cmake --install build` incorrectly looks for
    # `<source>/build/build/cmake_install.cmake` and breaks the full system build.
    # Upstream install rules place the library in `$out/lib` and the manifest in
    # `$out/share/vulkan/implicit_layer.d`. The manifest uses an absolute library
    # path, so no symlinkJoin/runtimePath workaround is needed. `LOW_LATENCY_LAYER_REFLEX=1`
    # is the relevant runtime setting; the old pinned-revision validation notes are
    # kept in the historical audit rather than repeated here.

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
    # list. The hook also calls `ls` (findutils) and `sed` (gnused); without those
    # runtime inputs, errors could be hidden and DRM-card detection could silently
    # fall back to card0. Include the required store paths explicitly.
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.systemd pkgs.findutils pkgs.gnused ]}:$PATH"
    export HOOK_SETPCI="${lib.getExe' pkgs.pciutils "setpci"}"
    export HOOK_FUSER="${lib.getExe' pkgs.psmisc "fuser"}"
    export HOOK_RTCWAKE="${lib.getExe' pkgs.util-linux "rtcwake"}"
    # Suspend/remove/rescan recovery is deliberately opt-in; default stays off.
    # To enable, set systemd.services.libvirtd.environment.VFIO_ALLOW_SUSPEND_RECOVERY = "1".
    export VFIO_ALLOW_SUSPEND_RECOVERY="''${VFIO_ALLOW_SUSPEND_RECOVERY:-0}"
    ${builtins.readFile ./hooks/qemu}
  '';

  # `wuwa-auto.sh` requests the `wuwa-gemma` Ollama model. The model definition is
  # embedded here and used by the systemd service to create the model.
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
    "amd_pstate=active" "nowatchdog" "nmi_watchdog=0"
    # IOMMU activation depends on the CPU, kernel, and platform firmware/BIOS.
    # `iommu=pt` selects passthrough-oriented DMA mapping; it does not prove that IOMMU
    # is enabled by firmware. Verify at runtime using `dmesg` and `/sys/kernel/iommu_groups`.
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
  boot.kernelModules = [ "kvm-amd" "binder_linux" "vfio-pci" ];

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
    { domain = "localhost"; item = "nofile"; type = "hard"; value = "65536"; }
    { domain = "localhost"; item = "nofile"; type = "soft"; value = "65536"; }
  ];

  security.apparmor.enable = true;
  # The sshd fail2ban jail can ban repeated failed SSH attempts from logs even when
  # password authentication is disabled. No authorized keys are configured by default,
  # so enabling SSH does not automatically create password-based access.
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    # RFC1918 home/LAN ranges are exempt for convenience. This also means compromised
    # or hostile devices on the local network will not be banned by fail2ban; narrow
    # the exception if the LAN is not trusted.
    ignoreIP = [
      "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16"
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
  networking.hostName = "nixos-workstation";
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/Istanbul";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "tr_TR.UTF-8/UTF-8" ];
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
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE = "16";
    # The pinned low-latency-layer source reads `LOW_LATENCY_LAYER_REFLEX`,
    # `LOW_LATENCY_LAYER_SPOOF_NVIDIA`, and `LOW_LATENCY_LAYER_FORCE_DECOUPLED`.
    # Its manifest uses `DISABLE_LOW_LATENCY_LAYER` as the environment gate and does
    # not define `enable_environment`, so the layer is enabled by default. There is no
    # `LOW_LATENCY_LAYER` variable; setting it would be a no-op. Reflex mode uses
    # `LOW_LATENCY_LAYER_REFLEX`. `SPOOF_NVIDIA` is intentionally not enabled globally;
    # upstream recommends setting it per game.
    LOW_LATENCY_LAYER_REFLEX = "1";
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
      # The wrapper exports HYPRLAND_CONFIG and execs Hyprland without
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
      "wheel" "networkmanager" "video" "audio" "storage"
      "gamemode" "libvirtd" "kvm" "input" "render"
    ];
    openssh.authorizedKeys.keys = [
      # The previous configuration embedded the maintainer's public SSH key, which could
      # authorize remote access for every installation while blocking the new owner's key.
      # Add your own key with `ssh-keygen -t ed25519` and copy the `.pub` value below.
      # The list is intentionally empty by default and password/root SSH login is disabled;
      # remote SSH stays unavailable until you add a key. Disable `services.openssh` if
      # remote access is not needed.
      # Example: "ssh-ed25519 AAAA... user@host"
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
    kitty waybar rofi dunst grim slurp wl-clipboard
    # The `argos-translate` binary is not available as a nixpkgs package (only the
    # `argos-translate-files` Python package is present). Do not add a nonexistent binary
    # package: `wuwa-auto.sh` checks for the command and falls back to Ollama if absent.
    # An external flake can be added if Argos support is required.
    hyprlock hypridle wlogout hyprpicker
    hyprpolkitagent pyprland waypaper
    networkmanagerapplet brightnessctl playerctl
    pavucontrol cliphist libmtp android-file-transfer
    ntfs3g exfat android-file-transfer gparted crow-translate tesseract translate-shell libnotify
    steam gamemode gamescope mangohud winetricks procps
    heroic protonup-qt wine nodejs
    virt-manager capitaine-cursors
    btop nvtopPackages.amd fastfetch
    git zip unzip usbutils pciutils p7zip android-tools
    (vscode-with-extensions.override {
      vscode = vscode.fhs;
      vscodeExtensions = with vscode-extensions; [ continue.continue ];
    })
    brave telegram-desktop discord proton-vpn fzf input-remapper yt-dlp ffmpeg cloudflare-warp
    qbittorrent flatpak gnome-software wev pcmanfm
    imagemagick
    btrfs-progs compsize snapper
    whois # mkpasswd --method yescrypt (password hash setup)
    mpvpaper flatpak-builder psmisc
    apparmor-utils stdenv.cc.cc.lib kdePackages.konsole kdePackages.dolphin
    low-latency-layer vulkan-tools
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

  # With `qemu.runAsRoot = false`, libvirt opens disk and NVRAM files as
  # `qemu-libvirtd`. Existing files created by root can cause `virsh start win10` to
  # fail with `Permission denied`; the oneshot service fixes ownership before libvirtd.
  systemd.services.libvirtd-qemu-ownership = {
    description = "Fix ownership of libvirt images/NVRAM for qemu-libvirtd";
    wantedBy = [ "multi-user.target" ];
    before = [ "libvirtd.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # The libvirtd module creates the `qemu-libvirtd` user/group. Ignore a chown failure
    # if activation runs before the account exists.
    script = ''
      # Do not change ownership of `/var/lib/libvirt` itself; it contains privileged
      # libvirt state and hook files. Fix only the relevant working directories and their
      # first-level children rather than recursively changing the entire tree.
      for d in /var/lib/libvirt/images /var/lib/libvirt/qemu /var/lib/libvirt/swtpm; do
        if [ -d "$d" ]; then
          chown qemu-libvirtd:qemu-libvirtd "$d" 2>/dev/null || true
          find "$d" -maxdepth 2 -exec chown -h qemu-libvirtd:qemu-libvirtd {} + 2>/dev/null || true
        fi
      done
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
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
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
      "https://attic.xuyh0120.win/lantian"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
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
    description = "Ollama için wuwa-gemma modelini oluşturur (elle çalıştırılır)";
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];
    wantedBy = [ ];               # otomatik başlatMA
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
            echo "HATA: Ollama API yaklaşık 30 sn içinde hazır olmadı." >&2
            exit 1
          fi
          echo "Ollama API henüz hazır değil ($attempt/15); 2 sn sonra yeniden denenecek."
          sleep 2
        done

        if ${cfgpkg}/bin/ollama list | grep -q '^wuwa-gemma'; then
          echo "wuwa-gemma zaten var, atlanıyor."
        else
          echo "aya-expanse:8b çekiliyor (yaklaşık 8 GB)…"
          if ! ${cfgpkg}/bin/ollama pull aya-expanse:8b; then
            echo "HATA: aya-expanse:8b indirilemedi; wuwa-gemma oluşturulmadı." >&2
            exit 1
          fi
          ${cfgpkg}/bin/ollama create wuwa-gemma -f ${wuwaGemmaModelfile}
          echo "wuwa-gemma hazır."
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

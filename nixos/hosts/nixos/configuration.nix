{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Start Hyprland under uwsm (Universal Wayland Session Manager) from the
  # greetd session command: the compositor then runs as the systemd user
  # unit wayland-wm@Hyprland.service inside a uwsm-prepared environment,
  # and session shutdown stops that unit and unexports the session
  # environment. The native Lua config path is still exported directly in
  # this wrapper: `uwsm start` saves the calling environment and applies it
  # to the session, so the login keeps working without environment.d or a
  # pre-imported systemd user environment. If uwsm exits non-zero (for
  # example the user manager or its D-Bus socket is not reachable from
  # greetd), fall back to the previous direct exec so a failed experiment
  # can never take the graphical login down with it. `uwsm check
  # may-start` is deliberately NOT used here: its login-shell-parent and
  # tty-foreground checks target shell-profile autostart, not a
  # display-manager session command, and would always fail under tuigreet.
  # The manual environment import and unit starts in home.nix
  # (systemdEnvironmentCommand) stay untouched during the experiment and
  # are removed only after host validation shows uwsm covers them.
  greetdHyprlandSession = pkgs.writeShellScript "greetd-hyprland-session" ''
    export HYPRLAND_CONFIG="/home/localhost/.config/hypr/hyprland.lua"
    if ! ${pkgs.uwsm}/bin/uwsm start -- ${pkgs.hyprland}/bin/Hyprland "$@"; then
      echo "uwsm start failed; falling back to direct Hyprland exec" >&2
      exec ${pkgs.hyprland}/bin/Hyprland "$@"
    fi
  '';

  # Build the v2 Vulkan layer/UI/CLI from the pinned upstream source. The archived
  # pabloaul NixOS module is v1-only and cannot read the v2 profile schema.
  lsfgVkV2 = pkgs.callPackage ../../lsfg-vk-v2.nix { };

  # Pin the tested upstream scroll-bounce filter. Build its C++ daemon and
  # platform-independent filter tests directly; runtime needs only evdev/uinput.
  mouseHardwareFix = pkgs.stdenv.mkDerivation {
    pname = "mouse-hardware-fix";
    version = "2026-10-05";

    src = builtins.fetchGit {
      url = "https://github.com/Aleynikovich/mouse-hardware-fix.git";
      ref = "refs/heads/main";
      rev = "9cb3bc2ae313cac8fbe60dc573955cb68a0354ae";
    };

    buildPhase = ''
      runHook preBuild
      $CXX -std=c++17 -O2 -Wall -Wextra -I. mouse-hardware-fix.cpp -o mouse-hardware-fix
      $CXX -std=c++17 -O2 -Wall -Wextra -I. tests/filter-test.cpp -o filter-test
      runHook postBuild
    '';
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      ./filter-test
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 mouse-hardware-fix $out/bin/mouse-hardware-fix
      runHook postInstall
    '';

    meta = {
      description = "Userspace filter for mouse scroll-wheel encoder bounce";
      homepage = "https://github.com/Aleynikovich/mouse-hardware-fix";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

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
    # The upstream manifest registers an implicit Vulkan layer. Enable it globally with
    # LOW_LATENCY_LAYER=1 while retaining the default AMD Anti-Lag interface. Compatible
    # Proton games can opt into Reflex per game; incompatible games can opt out with
    # DISABLE_LOW_LATENCY_LAYER=1.

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
    # list. The hook uses `ls`, `awk` (gawk), and `sed` (gnused); without these
    # runtime inputs, commands may be missing and service/DRM recovery can fail.
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
  imports = [
    ./hardware-configuration.nix
    # host-settings.nix declares the host-specific NixOS options (monitor,
    # wallpaper, git identity); home.nix reads them through osConfig.kumutuk.host
    # while Home Manager runs as a NixOS module.
    ./host-settings.nix
  ];

  # Media partition
  fileSystems."/mnt/media" = {
    device = "/dev/disk/by-uuid/34609584-8e72-4a79-b076-5ece7e60ed71";
    fsType = "ext4";
    options = [
      "nofail"
      "noatime"
    ];
  };

  assertions = [
    {
      assertion = lib.versionAtLeast config.programs.hyprland.package.version "0.55.0";
      message = "The Hyprland Lua configuration requires Hyprland 0.55.0 or newer.";
    }
  ];

  hardware.enableRedistributableFirmware = true;

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  # Deprecated hook deployment path. libvirt does not read `/etc/libvirt/hooks` in
  # this NixOS configuration; `virtualisation.libvirtd.hooks.qemu` installs the hook
  # under `/var/lib/libvirt/hooks/qemu.d/` instead.

  boot.loader.systemd-boot.enable = true;
  # Bound the boot-entry count so generations cannot fill the 1 GiB ESP and
  # break booting. Store generations remain governed by the weekly nix.gc
  # 30-day retention; snapper snapshots are independent of the ESP entry list.
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  # Apple Aluminium Keyboard (USB ID 05ac:024f) exposes the F-row as media keys
  # in hid_apple's automatic mode. Prefer standard F1-F12 keys; hold Fn for media.
  boot.extraModprobeConfig = ''
    options hid_apple fnmode=2
  '';

  boot.kernelParams = [
    # Diagnostic trade-off: `nowatchdog` and `nmi_watchdog=0` disable kernel/NMI
    # watchdog-based lockup detection. This favors lower jitter but reduces diagnostic
    # information if the host unexpectedly locks up.
    "amd_pstate=active"
    # The pinned CachyOS RT-Bore-LTO 7.3.4 config sets CONFIG_ZSWAP_DEFAULT_ON=y.
    # ZRAM is the selected compressed swap tier; disable ZSwap to avoid a second
    # compression layer before the higher-priority zram and lower-priority disk swap.
    "zswap.enabled=0"
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

  # These optional Rust drivers are not used by this x86_64 host. The 7.3.3
  # CachyOS RT-Bore-LTO BTF failures (rnull_mod.ko, then rcpufreq_dt.ko) are
  # historical; the current flake.lock resolves 7.3.4. Keep this narrow workaround
  # until a later exact-lock full-system build justifies removing it. General Rust,
  # BTF, and ThinLTO remain enabled.
  boot.kernelPatches = [
    {
      name = "disable-unused-rust-drivers-for-btf-lto";
      patch = null;
      structuredExtraConfig = {
        BLK_DEV_RUST_NULL = lib.kernel.no;
        CPUFREQ_DT_RUST = lib.kernel.no;
      };
    }
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
  # `ntsync` (mainline since 6.14) implements the Windows game-synchronization
  # primitives that Wine/Proton 10+ use for lower input-to-frame latency. Wine
  # falls back to its own userspace implementation when the module is absent,
  # so this is an optimization, not a dependency. VFIO is unaffected: ntsync
  # owns no PCI device. Verify availability with `modinfo ntsync`.
  # `tcp_bbr` loads the BBRv3 congestion-control module so the
  # net.ipv4.tcp_congestion_control sysctl below can select it.
  boot.kernelModules = [
    "kvm-amd"
    "binder_linux"
    "vfio-pci"
    "ntsync"
    "tcp_bbr"
  ];

  # Known-good recovery boot entry: the same host definition evaluated with
  # the CachyOS LTS kernel (no LTO, plain x86-64 baseline) from the pinned
  # nix-cachyos-kernel overlay. It appears as an additional systemd-boot entry
  # ("...-lts-kernel"); the primary entry, the default boot order, and the
  # RT-Bore-LTO selection are unchanged. LTS builds faster than the LTO kernel
  # and does not track the same upstream churn, so it is the fallback when a
  # new RT-Bore-LTO revision fails on target hardware. mkForce is required
  # because the flake module assigns boot.kernelPackages at default priority;
  # the override applies only inside this specialisation's evaluation. VFIO
  # and the qemu hook depend on module availability, not the kernel variant.
  # Target-host boot of the LTS specialisation remains unverified until the
  # next full-system build and activation.
  specialisation.lts-kernel.configuration = {
    boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-lts;
  };

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.nr_hugepages" = 0;
    # Swap priority selects which swap device is used first: higher values take
    # precedence. zram priority 100 remains above the encrypted disk-swap priority 10.
    # Leave vm.swappiness at the kernel/NixOS default rather than forcing earlier reclaim.
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.perf_event_paranoid" = 1;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 512;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_fastopen" = 3;
    # BBR congestion control: CachyOS kernels carry BBRv3 alongside cubic, and
    # BBR probes available bandwidth instead of reacting to loss with queue
    # draining, which benefits interactive TCP flows (game traffic, VPNs).
    # `fq` is the pacing qdisc BBR requires. Cloudflare WARP routes through its
    # own userspace path and is unaffected. Verify at runtime:
    # `sysctl net.ipv4.tcp_congestion_control` must report bbr; if the kernel
    # ever drops BBR, systemd-sysctl logs an error and traffic stays on cubic.
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
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
  # Fail2ban monitors repeated SSH authentication failures as defence in depth; SSH uses public keys by default.
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

  # USB device-policy daemon in audit-safe mode: every device keeps working.
  # Unmatched devices are allowed and logged (implicitPolicyTarget=allow) and
  # devices already connected at daemon start keep their current state
  # (presentDevicePolicy=keep), so a misgenerated rule cannot lock out the
  # keyboard or the VM-passed-through mouse on activation. Enforcement is a
  # deliberate later step: generate an allowlist with `usbguard
  # generate-policy`, review it, switch implicitPolicyTarget to "block", and
  # rebuild. The IPC socket grants rule inspection to the desktop user.
  services.usbguard = {
    enable = true;
    implicitPolicyTarget = "allow";
    presentDevicePolicy = "keep";
    IPCAllowedUsers = [
      "root"
      "localhost"
    ];
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

  # Use systemd-oomd as the sole userspace OOM manager. NixOS enables its daemon
  # by default, but slice monitoring must be opted into explicitly. This follows
  # Fedora's root/user-slice policy; EarlyOOM is deliberately not enabled alongside it.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  # BPF-Land is the selected sched_ext policy. The kernel's RT-Bore/BORE scheduler
  # remains the fallback whenever sched_ext is stopped or cannot be activated.
  # The policy name comes from host-settings (kumutuk.host.schedScheduler);
  # every enum value ships in the scx.rustscheds package set the service
  # installs, so switching to lavd/rusty/flash/p2pq/cake is a one-line
  # host-settings change and needs no extra package wiring.
  services.scx-loader = {
    enable = true;
    config.default_sched = config.kumutuk.host.schedScheduler;
  };

  # Three components can change CPU scheduling/priority for distinct purposes:
  # power-profiles-daemon controls the governor, sched_ext selects the normal-task
  # scheduler, and GameMode's renice = 10 is negated to nice value (-10), raising
  # CPU scheduling priority when GameMode successfully applies it.
  # Ananicy-cpp is intentionally disabled to avoid another overlapping policy.
  # Use a balanced desktop power profile outside games.
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # The reference host mounts only local filesystems; do not hold boot for network-online.
  # Re-enable this if a future remote mount or service requires network-online ordering.
  systemd.services.NetworkManager-wait-online.enable = false;
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
    # KDE Connect is enabled below; its NixOS module independently opens TCP and UDP
    # ports 1714–1764. Do not treat that application-specific range as generic P2P/seed
    # access: add only the specific ports those services require to the lists above.
    allowPing = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    # The `nggc` flag was removed because NGG culling is already enabled by default
    # in Mesa for GFX10.3 (RX 6700 XT); the flag had no effect. The `gpl` setting remains.
    RADV_PERFTEST = "gpl";
    # Mesa's default on-disk shader cache is small enough that large games evict
    # compiled shaders and recompile them on later launches (startup stutter).
    # 12G follows the CachyOS gaming recommendation; the cache is per-user under
    # ~/.cache, and DXVK/Proton keep their separate caches inside prefixes.
    MESA_SHADER_CACHE_MAX_SIZE = "12G";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    # Keep the system fallback aligned with Home Manager and Hyprland startup.
    XCURSOR_THEME = "Plus-Cursor";
    XCURSOR_SIZE = "20";
  };

  # PAM initializes these variables for login sessions, including greetd/Hyprland.
  # Enable the latency layer globally but keep its default AMD Anti-Lag interface.
  # Compatible Proton games can opt into Reflex with LOW_LATENCY_LAYER_REFLEX=1 per game;
  # incompatible games can opt out with DISABLE_LOW_LATENCY_LAYER=1.
  environment.sessionVariables = {
    LOW_LATENCY_LAYER = "1";
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
      # The wrapper exports the Lua HYPRLAND_CONFIG and starts Hyprland under
      # uwsm with a direct-exec fallback; its store path contains no shell
      # quoting.
      command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd ${greetdHyprlandSession}";
      user = "greeter";
    };
  };

  # Preserve hardware ALSA mixer state (for example, ALC897 capture gain) across
  # shutdowns and restore it when the sound card appears. This does not enable
  # standalone ALSA in place of PipeWire, choose an input jack, or set gain values.
  hardware.alsa.enablePersistence = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    # QEMU runs as the unprivileged qemu-libvirtd account. A system-wide
    # PipeWire socket lets it stream the ICH9 guest audio without running QEMU
    # as root; access is restricted to members of the dedicated pipewire group.
    systemWide = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    # Keep the reference-host VG27AQ1A DisplayPort sink open between media streams.
    # Its idle suspend caused a 2–3 second audio resume delay; scope this to one sink.
    wireplumber.extraConfig."51-vg27aq1a-no-suspend" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {
              "node.name" = "alsa_output.pci-0000_0b_00.1.hdmi-stereo-extra4";
            }
          ];
          actions = {
            update-props = {
              "session.suspend-timeout-seconds" = 0;
            };
          };
        }
      ];
    };
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
  virtualisation.waydroid.package = pkgs.waydroid-nftables;
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  # fstrim stays off: every Btrfs mount already uses discard=async and the LUKS
  # device allows discards, so freed extents are trimmed continuously. A weekly
  # fstrim pass would add I/O without reclaiming anything further.
  services.fstrim.enable = false;

  # S.M.A.R.T. health monitoring for the NVMe system disk and the media disk.
  # smartd auto-detects devices and reports findings to the journal; direct
  # mail notification is disabled because this host runs no mail transport.
  services.smartd.enable = true;
  services.smartd.notifications.mail.enable = false;

  # LVFS firmware updates through `fwupdmgr` (UEFI/NVMe). Keep a known-good
  # boot generation available before applying UEFI-level updates.
  services.fwupd.enable = true;

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
    # Allow swap capacity up to 100% of detected RAM (~32 GB on this host).
    # This is a logical zram limit, not an eager reservation of physical RAM.
    memoryPercent = 100;
    algorithm = "lz4";
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
      "pipewire"
      "gamemode"
      "libvirtd"
      "kvm"
      "input"
      "render"
    ];
    openssh.authorizedKeys.keys = [
      # Add your own public key here before relying on remote SSH access. Password
      # and keyboard-interactive SSH authentication are disabled by default. Never
      # commit a private key. Example: "ssh-ed25519 AAAA... user@host"
    ];
  };

  # The libvirt module creates this unprivileged QEMU account because
  # virtualisation.libvirtd.qemu.runAsRoot is false. Grant only the PipeWire
  # group required by the VM's ICH9 audio backend.
  users.users.qemu-libvirtd.extraGroups = [ "pipewire" ];

  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  hardware.uinput.enable = true;
  services.udev.packages = [ pkgs.libinput ];

  # Intercept only the Razer DeathAdder Essential pointer node (1532:0098).
  # The daemon clones it through uinput, filters scroll bounce, and leaves other
  # mice, keyboard interfaces, and all physical mouse buttons untouched.
  # The second rule opens the ntsync character device to the default `users`
  # group (0660, tighter than the 0666 used by some upstream examples) so
  # Steam/Proton do not need root for NT sync objects.
  # The remaining rules pin per-device-class I/O schedulers (CachyOS 60-ioschedulers
  # style): rotational disks get BFQ fair queuing, NVMe namespaces get `none`
  # because software queuing only adds latency on multi-queue devices. SATA/SD
  # SSDs keep the kernel default (mq-deadline). The rules mostly make the
  # defaults explicit; their real value is automatic correct selection when a
  # media HDD is added. Note: `none` on NVMe hides queue stats from some
  # telemetry tools. Unavailable schedulers are ignored by the kernel.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0098", TAG+="systemd", ENV{SYSTEMD_WANTS}+="mouse-hardware-fix@%k.service"
    KERNEL=="ntsync", MODE="0660", GROUP="users"
    ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
  '';

  # The udev rule starts this template for the matching physical Razer pointer.
  # EVIOCGRAB prevents duplicate raw events; if the service exits, the kernel
  # releases the grab and the original mouse resumes working.
  systemd.services."mouse-hardware-fix@" = {
    description = "Razer DeathAdder scroll-wheel bounce filter";
    unitConfig.BindsTo = "dev-input-%i.device";
    after = [ "dev-input-%i.device" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${mouseHardwareFix}/bin/mouse-hardware-fix --device /dev/input/%I --only 1532:0098 --disable-click --scroll-timeout 0.300 --scroll-reversal 2 --verbose";
      Restart = "on-failure";
      RestartSec = "1s";

      # The daemon needs only its matched evdev node and the uinput device.
      DevicePolicy = "closed";
      DeviceAllow = [
        "/dev/input/%I r"
        "/dev/uinput rw"
      ];
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateNetwork = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = "AF_UNIX";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

  # Hyprlock needs a PAM service so the lock screen can authenticate. The NixOS
  # `security.pam` module generates `/etc/pam.d/hyprlock`; there is no systemd
  # `hyprlock.service` in this configuration. The empty service definition activates
  # the generated PAM file and uses the module defaults. A custom `backend = "pam_unix.so"`
  # was rejected because that option does not exist. Verify with `ls -l /etc/pam.d/hyprlock`
  # and `grep -c pam_unix /etc/pam.d/hyprlock`.
  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    brave-origin
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
    # Btrfs compression report behind the `btrfs-cmp` shell alias.
    compsize
    # Qt 6 GUI over the snapper configs above (root and home): snapshot
    # browsing and diffs need no extra setup because ALLOW_USERS already
    # includes `localhost`, and privileged actions ride the package's polkit
    # daemon. Its own balance/scrub scheduling is cron-shaped for traditional
    # distros and stays unused: maintenance remains declarative via
    # services.btrfs.autoScrub.
    btrfs-assistant
    snapper
    nh # nixos-rebuild helper with generation diffs and cleanup
    nvd # side-by-side NixOS generation/package-set diffing
    nix-output-monitor # live rebuild progress and build-time summary (nom)
    whois # mkpasswd --method yescrypt (password hash setup)
    mpvpaper
    flatpak-builder
    psmisc
    apparmor-utils
    stdenv.cc.cc.lib
    kdePackages.konsole
    kdePackages.dolphin
    low-latency-layer
    lsfgVkV2
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

  # This explicit /etc entry is intentional: it provides the system-level Vulkan
  # loader manifest registration in addition to the copy shipped by the package.
  environment.etc."vulkan/implicit_layer.d/low_latency_layer.json".source =
    "${low-latency-layer}/share/vulkan/implicit_layer.d/low_latency_layer.json";

  # Register the pinned v2 package's implicit Vulkan layer manifest. Its library
  # path points to the same store output installed in environment.systemPackages.
  environment.etc."vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json".source =
    "${lsfgVkV2}/share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json";

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 0;
        inhibit_screensaver = 1;
        softrealtime = "off";
        reaper_freq = 5;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 1;
        amd_performance_level = "high";
      };
      # Switch the power profile on game start/end (CachyOS game-performance
      # equivalent for the profile half): performance while a game runs,
      # balanced afterwards — the desktop default this configuration keeps.
      # powerprofilesctl comes from power-profiles-daemon and authorizes
      # active local sessions, so no password prompt appears in practice.
      # These scripts only touch the PPD profile: `mpvpaper-watchdog` remains
      # the single authority for the live-wallpaper service. A failed switch
      # is logged by gamemoded and never blocks the game itself.
      custom = {
        start = "powerprofilesctl set performance";
        end = "powerprofilesctl set balanced";
      };
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
  # Declarative GE Proton: pinned by nixpkgs and the flake lock instead of
  # manual protonup-qt downloads, and selectable per game in Steam's
  # compatibility menu. Valve Proton stays the global default; protonup-qt
  # remains available for ad-hoc, unpinned installs.
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];
  # Console-like Steam session: one additional entry in the greetd session
  # list; the default login remains Hyprland. Inside this session, Gamescope
  # is the compositor, so games page-flip without the desktop layer (Waybar,
  # mpvpaper, Pyprland) in the frame path. The CS2 per-game gamescope launch
  # line is unnecessary inside this session; use plain `gamemoderun mangohud
  # %command%` there. Resolution matches the reference 2560x1440 monitor.
  programs.steam.gamescopeSession = {
    enable = true;
    args = [
      "-W"
      "2560"
      "-H"
      "1440"
      "-f"
      "--immediate-flips"
      "--force-grab-cursor"
    ];
  };
  services.flatpak.enable = true;
  services.cloudflare-warp.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    # swtpm lets the Windows guests use an emulated TPM 2.0 (tpm-crb in both
    # vm-xml templates; Windows 11 requires it).
    qemu.swtpm.enable = true;
    # When `runAsRoot = false`, QEMU runs as `qemu-libvirtd`. Disk/NVRAM files left
    # owned by root can prevent the guest from starting, so the oneshot service repairs
    # ownership at each boot.
    qemu.runAsRoot = false;

    # libvirt scans this hook directory: `/var/lib/libvirt/hooks/qemu.d/vfio`.
    hooks.qemu.vfio = vfioHook;
  };

  # The Windows templates carry a read-only virtiofs share of /mnt/media/win-share
  # (guest tag `host-share`). libvirt spawns the Rust virtiofsd from the
  # libvirtd service PATH; the module has no dedicated option for it, so it is
  # added here. The share is deliberately read-only in the XML: a compromised
  # guest cannot write host files.
  systemd.services.libvirtd.path = [ pkgs.virtiofsd ];
  systemd.tmpfiles.rules = [
    # Created at boot when missing so libvirt never fails on an absent share.
    "d /mnt/media/win-share 0755 root root -"
  ];
  programs.virt-manager.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      # Require public-key authentication. Add the account owner's own public key
      # under users.users.localhost.openssh.authorizedKeys.keys before relying on SSH.
      # AllowUsers limits the login name, not the source IP; restrict port 22 at the
      # network edge or with an appropriate host-firewall allow-list as well.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PubkeyAuthentication = true;
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
    # This project's own Cachix cache serves the selected RT-Bore-LTO kernel
    # closure (no upstream publishes it), so a kernel-input bump downloads
    # instead of compiling locally for hours once the cache workflow has run.
    substituters = [
      "https://kumutuk-nixos-hyprland-vfio.cachix.org"
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "kumutuk-nixos-hyprland-vfio.cachix.org-1:wgWsd619A9+2Mj+iEDABPbnIB1YqJnVJWt2D7Bv9JTQ="
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

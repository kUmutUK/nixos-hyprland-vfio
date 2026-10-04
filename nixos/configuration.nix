{ config, pkgs, lib, ... }:

let

  # --------------- low_latency_layer türetmesi ---------------
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

    # Upstream'in kendi install kuralı kullanılıyor. CMakeLists.txt hem .so'yu
    # $out/lib altına, hem de DOĞRU manifesti $out/share/vulkan/implicit_layer.d/
    # altına kopyalıyor. Daha önce elle yazılmış bir manifest
    # (low_latency_layer.json.in) kullanılıyordu; o dosyada hem yanlış katman
    # adı/api sürümü vardı hem de "functions" eşlemesi yoktu. En kötüsü:
    # enable_environment: ENABLE_LOW_LATENCY_LAYER eklenmişti, ama o değişken
    # hiçbir yerde set edilmiyordu — Vulkan loader katmanı bu yüzden
    # SESSİZCE atlıyor ve Reflex/Anti-Lag hiç çalışmıyordu.
    # Upstream manifestinde enable_environment YOKTUR: bu rev'de katman
    # varsayılan olarak etkindir, sadece disable_environment ile kapatılır.
    installPhase = ''
      runHook preInstall
      cmake --install .
      runHook postInstall
    '';

    meta = with lib; {
      description = "Vulkan layer for hardware agnostic input latency reduction (Reflex/Anti-Lag)";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  };

  # ─── libvirt VFIO hook ──────────────────────────────────────────────
  # libvirt, hook'u SADECE $SYSCONFDIR/libvirt/hooks altından arar. nixpkgs
  # libvirt'i --sysconfdir=/var/lib ile derdiği için bu yol
  # /var/lib/libvirt/hooks olur; libvirt bu dizini ve <dizini>/qemu.d/
  # içindeki dosyaları tarar. /etc/libvirt/hooks HİÇ okunmaz.
  #
  # Daha önce environment.etc."libvirt/hooks/qemu" ile /etc'ye kopyalanıyordu;
  # libvirt onu görmüyor, hook hiç çalışmıyor, GPU vfio-pci'ye hiç bağlanmıyordu.
  #
  # Shebang de ayrı bir sorundu: libvirtd.service'in PATH'i yalnızca
  # qemu + netcat + swtpm içeriyor, bash yok. Bu yüzden bash ve coreutils
  # store yolundan garanti ediliyor.
  #
  # psmisc/pciutils/util-linux de PATH'e ekleniyor: hook'ta üç ayrı araç
  # çağrılıyor ve bunları /run/current-system/sw/bin üzerinden çağırmak,
  # yani environment.systemPackages'a bağımlı kılmak kırılgan idi —
  # systemPackages'tan biri düşerse (ör. psmisc) hook sessizce fuser'ı
  # bulamaz ve stop_hyprland() bekleme döngüsü anında çöker. Artık store
  # yolları aşağıda HOOK_* değişkenleri olarak enjekte ediliyor; hook bu
  # değişkenleri kullanıyor, tanımlı değillerse /run/current-system/sw/bin'e düşüyor.
  vfioHook = pkgs.writeShellScript "libvirt-vfio-hook" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}:$PATH"
    export HOOK_SETPCI="${lib.getExe' pkgs.pciutils "setpci"}"
    export HOOK_FUSER="${lib.getExe' pkgs.psmisc "fuser"}"
    export HOOK_RTCWAKE="${lib.getExe' pkgs.util-linux "rtcwake"}"
    ${builtins.readFile ./hooks/qemu}
  '';

  # wuwa-auto.sh, Ollama'dan "wuwa-gemma" modelini istiyor. Modelfile içeriği
  # burada Nix'e gömülüyor; systemd servisi bunu kullanarak modeli oluşturur.
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

  # ESKİ YOL (KALDIRILDI): environment.etc."libvirt/hooks/qemu" = { … };
  # libvirt /etc/libvirt/hooks dizinini okumaz; hook aşağıdaki
  # virtualisation.libvirtd.hooks.qemu ile /var/lib/libvirt/hooks/qemu.d/
  # altına symlink olarak kurulur.

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "amd_pstate=active" "nowatchdog" "nmi_watchdog=0"
    "transparent_hugepage=madvise" "amd_iommu=on" "iommu=pt"
    "usbcore.autosuspend=-1" "video=efifb:off"
    "amdgpu.ppfeaturemask=0xfffd7fff" "kvm.ignore_msrs=1"
    "pcie_aspm=off" "rcupdate.rcu_expedited=1"
  ];

  boot.initrd.availableKernelModules = lib.mkAfter [ "amdgpu" ];
  boot.initrd.kernelModules = [ "dm-crypt" "amdgpu" ];
  # ⚠️ "ashmem_linux" BURADAN KALDIRILDI. ashmem Linux 5.18'de tamamen
  # kaldırıldı; CachyOS BORE 6.18'de modprobe ashmem_linux her boot'ta
  # "FATAL: Module not found" veriyor. Waydroid 5.18+ ashmem yerine memfd
  # kullanıyor. `sudo waydroid init` sonrası şunu bir kez doğrula:
  #   grep sys.use_memfd=true /var/lib/waydroid/waydroid_base.prop
  # yoksa: echo sys.use_memfd=true | sudo tee -a /var/lib/waydroid/waydroid_base.prop
  boot.kernelModules = [ "kvm-amd" "binder_linux" "vfio-pci" ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
    "vm.nr_hugepages" = 0;
    "vm.swappiness" = 10;
    "kernel.sched_autogroup_enabled" = 0;
    "kernel.split_lock_mitigate" = 0;
    "kernel.perf_event_paranoid" = 1;
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

  security.apparmor.enable = true;
  services.fail2ban = {
    enable = true;
    maxretry = 5;
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
  networking.hostName = "nixos";
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
    # 1714-1764 aralığı (51 port) açıktı. Bu, bir "güvenlik" bölümü olan
    # config için gereksiz bir genişleme. P2P/seed istiyorsanız tek port
    # açın (örn. 51413). Şimdilik kaldırıldı.
    # allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    # allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
    allowPing = true;
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    # "nggc" kaldırıldı: NGG culling GFX10.3'te (RX 6700 XT) Mesa'da zaten
    # varsayılan olarak açık, bayrak etkisizdi. Geriye yalnızca gpl kalır.
    RADV_PERFTEST = "gpl";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE = "16";
    # Pinned low_latency_layer rev'inde (948a561) upstream yalnızca şu üç
    # değişkeni okuyor (src/layer_context.hh:52-61):
    #   LOW_LATENCY_LAYER_REFLEX          → VK_AMD_anti_lag sunulur mu
    #   LOW_LATENCY_LAYER_SPOOF_NVIDIA
    #   LOW_LATENCY_LAYER_FORCE_DECOUPLED
    # Upstream manifestindeki tek çevresel kapı ise
    # DISABLE_LOW_LATENCY_LAYER (low_latency_layer.json.in) ve bu rev'de
    # enable_environment YOKTUR → katman varsayılan olarak etkindir.
    #
    # ⚠️ "LOW_LATENCY_LAYER" diye bir değişken YOKTUR. Buraya daha önce
    # `LOW_LATENCY_LAYER = "1";` eklenmişti; hiçbir kod onu okumuyordu,
    # yani sessiz bir no-op'tu (config'in kendi düzelttiği
    # ENABLE_LOW_LATENCY_LAYER hatasının aynısı). Tekrar eklenmemeli.
    #
    # Reflex modu için gereken tek değişken LOW_LATENCY_LAYER_REFLEX.
    # SPOOF_NVIDIA bilinçli olarak sistem genelinde ayarlanmıyor: upstream
    # bunu oyun bazında öneriyor (README §Reflex → Steam başlatma seçeneği).
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
    # Kernel swap önceliğinde yükseği önce kullanır. Bu, zram'ı disk
    # swap'ten (priority = 10, hardware-configuration.nix) ÖNCE konumlandırır.
    # Doğrulandı: nix eval ile zramSwap.priority = 5 iken kernel önce disk
    # swap'i kullanıyordu, yani zram hiç devreye girmiyordu.
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
      # ⚠️ ÖNCEKİ HALİNDE proje bakımcısının (kUmutUK) açık anahtarı buradaydı.
      # Böylece bu configi kuran herkes, kendi anahtarı olmadan da o anahtarla
      # uzaktan giriş yapabiliyordu; kendi anahtarınız yoksa da SSH erişiminiz
      # kapalı kalıyordu (PasswordAuthentication = false).
      # Kendi anahtarınızı ekleyin:
      #   ssh-keygen -t ed25519
      #   cat ~/.ssh/id_ed25519.pub
      # ardından aşağıya yapıştırın.
      #
      # ⚠️ DİKKAT: liste BOŞ olduğu için (PasswordAuthentication = false,
      #    PermitRootLogin = "no" ile birlikte) uzaktan giriş TAMAMEN
      #    kapalıdır. Config'i güncelledikten sonra ssh ile bağlanmayı
      #    denemeden önce bir anahtar ekleyin. SSH kullanmayacaksanız
      #    services.openssh.enable = false yapmak daha temiz.
      # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... sizin@makine"
    ];
  };

  home-manager.users.localhost = import ./home.nix;
  home-manager.backupFileExtension = "backup";

  hardware.uinput.enable = true;
  services.udev.packages = [ pkgs.libinput ];

  environment.systemPackages = with pkgs; [
    kitty waybar rofi dunst grim slurp wl-clipboard
    hyprlock hypridle wlogout hyprpicker
    hyprpolkitagent pyprland waypaper
    networkmanagerapplet brightnessctl playerctl
    pavucontrol cliphist libmtp android-file-transfer
    ntfs3g exfat gparted crow-translate tesseract translate-shell libnotify
    steam gamemode gamescope mangohud vkbasalt winetricks
    heroic protonup-qt wine nodejs
    virt-manager looking-glass-client capitaine-cursors
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
    mpvpaper flatpak-builder psmisc
    apparmor-utils stdenv.cc.cc.lib kdePackages.konsole kdePackages.dolphin
    low-latency-layer vulkan-tools
    # wuwa-auto.sh "argos-translate" çağırıyordu ama paket hiçbir yerde
    # tanımlı değildi → translate_fast() her zaman sessizce başarısız oluyor,
    # her çeviri Ollama'ya düşüyordu. translate-shell (`trans`) bunun yerine geçmez.
  ];

  # home.nix'teki `home.persistence."/nix/persist/home"` tanımı bu dizini
  # kalıcı depolama kökü olarak kullanıyor. Dizin yoksa Home Manager
  # activation bind-mount'u sessizce başarısız oluyor ve ~/.config/lsfg-vk
  # oluşmuyor. tmpfiles kuralı boot başında idempotent çalışıp dizini
  # (gerekirse doğru sahiplikle) yeniden oluşturuyor; /nix bir btrfs alt
  # hacmi (nodatacow) olduğu için içerik diskte kalıcı.
  systemd.tmpfiles.rules = [
    "d /nix/persist/home 0755 localhost users -"
  ];

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
      custom = {
        # NOT: mpvpaper.service'i hem burada hem de home.nix içindeki
        # mpvpaper-watchdog yönetiyor. İkisi de systemctl start/stop
        # kullandığı için idempotent, ama oyun sırasında watchdog bir "start"
        # atarsa duvar kağıdı oyun bitmeden geri gelebilir. Tek kaynak
        # isterseniz aşağıdaki iki satırı silip yalnızca watchdog'u bırakın.
        start = "${pkgs.systemd}/bin/systemctl --user stop mpvpaper.service";
        end   = "${pkgs.systemd}/bin/systemctl --user start mpvpaper.service";
      };
    };
  };

  # qemu.runAsRoot = false iken libvirt, disk/NVRAM dosyalarını
  # `qemu-libvirtd` kullanıcısıyla açmak zorunda. NixOS'un kendi uyarısı:
  # "Changing this option to false may cause file permission issues for
  # existing guests." Daha önce root iken oluşturulmuş dosyalar root'a ait
  # kalırsa `virsh start win10` "Permission denied" ile başlamaz.
  # Aşağıdaki oneshot, libvirtd'den ÖNCE sahipliği düzeltir.
  systemd.services.libvirtd-qemu-ownership = {
    description = "Fix ownership of libvirt images/NVRAM for qemu-libvirtd";
    wantedBy = [ "multi-user.target" ];
    before = [ "libvirtd.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # qemu-libvirtd kullanıcı/grubu libvirtd modülü tarafından oluşturulur;
    # activation sırasında henüz yoksa chown hata vermesin diye `|| true`.
    script = ''
      for d in /var/lib/libvirt/images /var/lib/libvirt/qemu; do
        if [ -d "$d" ]; then
          chown -R qemu-libvirtd:qemu-libvirtd "$d" || true
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
    # ⚠️ runAsRoot = false → libvirt qemu'yu `qemu-libvirtd` kullanıcısıyla
    # çalıştırır. Daha önce root iken oluşturulmuş disk/NVRAM dosyaları
    # root'a ait kalırsa `virsh start win10` "Permission denied" ile başlamaz.
    # Aşağıdaki oneshot servisi her boot'ta sahipliği düzeltir.
    qemu.runAsRoot = false;

    # libvirt'in gerçekten taradığı yer: /var/lib/libvirt/hooks/qemu.d/vfio
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
  services.dbus.implementation = "broker";
  boot.initrd.systemd.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "10.3.0";
  };

  systemd.services.wuwa-gemma-init = {
    description = "Ollama için wuwa-gemma modelini oluşturur (elle çalıştırılır)";
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];
    wantedBy = [ ];               # otomatik başlatMA
    serviceConfig = {
      Type = "oneshot";
      Environment = "HOME=/root";
      ExecStart = pkgs.writeShellScript "wuwa-gemma-init" ''
        if ${pkgs.ollama-rocm}/bin/ollama list | grep -q '^wuwa-gemma'; then
          echo "wuwa-gemma zaten var, atlanıyor."
        else
          echo "aya-expanse:8b çekiliyor (yaklaşık 8 GB)…"
          ${pkgs.ollama-rocm}/bin/ollama pull aya-expanse:8b
          ${pkgs.ollama-rocm}/bin/ollama create wuwa-gemma -f ${wuwaGemmaModelfile}
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

  # ─── Impermanence ───────────────────────────────────────────────────
  # flake.nix impermanence modülünü import ediyor ama environment.persistence
  # burada TANIMLANMIYOR; bu yüzden her nixos-rebuild'de şu uyarı basılıyor:
  #   "environment.persistence: Neither /var/lib/nixos nor any of its parents
  #    are persisted. The following users are missing a uid: ... "
  #
  # ⚠️ Burada environment.persistence."/var/lib/nixos" tanımı EKLEMEK
  # denendi ve İKİ SEBEPLE GERİ ALINDI (gerçek `nix eval` ile ölçüldü):
  #   1) Uyarıyı SESSİZE ÇEVRİRMİYOR — tanım eklenmiş halde de aynı uyarı
  #      basılmaya devam ediyor.
  #   2) Impermanence'in güncel sürümünde `method` option'ı kaldırılmış
  #      durumda; persistence alt modülü zorlanınca
  #      "The option `method` can no longer be used since it's been removed"
  #      hatası veriyor. Yani uyarıyı susturmanın bedeli daha ağır.
  #
  # Gerçek etki düşük: `update-users-groups.pl` UID'leri /etc/passwd'deki
  # ilk boş slottan (allocId) seçtiği için pratikte her boot'ta aynı kalır.
  # Bu bir GÜRÜLTÜ uyarısıdır, hata değildir — build'i etkilemez.
  # Gerçekten susturmak isterseniz tek yol impermanence modülünü tamamen
  # kaldırmaktır (flake.nix + bu yorum + home.nix'deki home.persistence).
  #
  # /etc/vulkan/implicit_layer.d, environment.etc ile yazılıyor (Vulkan
  # manifesti salt-okunur bir store dosyası). Bu dizin bilinçli olarak
  # impermanence bind-mount'una VERİLMİYOR: persist dizini ilk açılışta
  # boş olduğu için etc dosyasını gölgeler ve Vulkan katmanı kaybolurdu.
  # home.persistence (home.nix) tarafındaki .config/lsfg-vk ise ayrı ve geçerli.

  # ─── DNS ────────────────────────────────────────────────────────────
  # ESKİ HALİ: services.nextdns + networking.networkmanager.dns = "none" +
  # nameservers = 127.0.0.1. Bu üçlü, nextdns geçersiz config ile başlamazsa
  # (config ID "xxxxxx" idi) sistemde HİÇ DNS çözümlemesi kalmıyordu.
  # Çözüm: nextdns devre dışı, DNS yine NetworkManager'ın yönetiminde.
  # Kendi NextDNS hesabınızı kullanmak istiyorsanız: servisi açın ve
  # arguments içindeki "xxxxxx" yerine GERÇEK DoH/DoT config ID'nizi yazın.
  #
  # services.nextdns = {
  #   enable = true;
  #   arguments = [ "-config" "<GERÇEK-CONFIG-ID>" ];
  # };

  # NOT: aşağıdaki iki satır bilinçli olarak yorumda. DNS çözümlemesi
  # NetworkManager'ın varsayılan davranışıyla (DHCP/DHCPv6) yapılır.
  # networking.networkmanager.dns = "none";
  # networking.nameservers = [ "127.0.0.1" "::1" ];

}

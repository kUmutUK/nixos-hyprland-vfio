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
    # Hook script LOGFILE="/var/log/libvirt/vfio.log" ile eşleşmeli.
    # "r!" → boot'ta dosyayı sil (log birikimini engeller).
    "r! /var/log/libvirt/vfio.log - - - -"
    # "d /etc/libvirt/hooks" KALDIRILDI: environment.etc dizini kendisi oluşturur.

    # FIX: VM disk imajları CoW yazma amplifikasyonu üretir → performans kaybı.
    # Bu dizin altındaki tüm dosyalarda nodatacow (Copy-on-Write kapalı) sağlanır.
    # NOT: nodatacow, btrfs sıkıştırmasını da devre dışı bırakır; disk imajları
    #   zaten kendi iç sıkıştırmasını yönetir, bu kabul edilebilir.
    "d /var/lib/libvirt/images 0751 root root - -"
    "a+ /var/lib/libvirt/images - - - - user:localhost:rwx"
  ];

  # ============================================================
  # VM Disk İmajları — nodatacow
  # Btrfs CoW, VM disk imajlarında rastgele yazma amplifikasyonu üretir.
  # chattr +C dizini ve içindeki dosyaları CoW dışı bırakır.
  # tmpfiles dizini oluşturur; bu servis chattr özelliğini uygular.
  # ============================================================
  systemd.services.libvirt-images-nodatacow = {
    description     = "Set nodatacow (+C) on libvirt images directory";
    wantedBy        = [ "libvirtd.service" ];
    before          = [ "libvirtd.service" ];
    serviceConfig   = {
      Type            = "oneshot";
      ExecStart       = "${pkgs.e2fsprogs}/bin/chattr +C /var/lib/libvirt/images";
      RemainAfterExit = true;
    };
  };

  # ============================================================
  # Libvirt Hook Script
  # NixOS 26.05 uyumu: system.activationScripts → environment.etc
  #
  # Neden değiştirildi:
  #   NixOS 26.05'te activation script'lerden systemd unit yönetimi
  #   deprecated edildi; uzun vadeli sürdürülebilirlik için environment.etc
  #   idiomatic NixOS yaklaşımıdır. Activation script'e gerek kalmaz.
  #
  # Nasıl çalışır:
  #   NixOS, /etc/libvirt/hooks/qemu'yu Nix store'daki read-only dosyaya
  #   sembolik bağ olarak oluşturur. mode="0755" çalıştırma iznini sağlar.
  #   Libvirt sembolik bağları takip ederek hook'u çalıştırır.
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

      # FIX [YENİ]: Ollama ROCm GPU'ya bağımlıdır. GPU vfio-pci'ye geçince
      # Ollama çöpebilir veya tutarsız duruma girer. Önceden durdurulur;
      # release aşamasında GPU host'a döndükten sonra yeniden başlatılır.
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
      # hugepages: VM'e ayrılacak 2MB büyük sayfa sayısı.
      # Hesaplama: VM RAM (GB) × 512 = hugepage sayısı.
      # Örnek: 4GB VM → 2048, 8GB VM → 4096.
      # Not: libvirt XML'de <memoryBacking><hugepages/></memoryBacking>
      # tanımlı olmalı; yoksa guest hugepage'leri kullanmaz.
      # Şu an 4GB VM için 2048 (= 4GB) ayrılıyor.
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
      # GÜVENLİK AĞI: Libvirt normalde stopped → release sırasıyla çağırır.
      # Olağandışı kapanış durumunda (crash, force-off) release tetiklenmeyebilir.
      # GPU hala vfio-pci'de bağsız kalırsa host ekran çıkışı olmaz.
      # Kısa bekleme sonrası amdgpu yüklenmediyse buradan rebind denenebilir:
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
      # NOT: modprobe -r drm_kms_helper KALDIRILDI.
      # Linux 6.2+'den itibaren drm_kms_helper ayrı modül değil, drm içine
      # merge edildi. CachyOS BORE 6.x bu modülü tanımaz → dead code.
      # ttm hala ayrı modül olarak var (6.x'te de), bu satır korunuyor.
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
        # if/else: drivers_probe başarısız olduğunda bind_driver fallback'e
        # geçiliyor. &&/|| zinciri shell önceliği nedeniyle her iki log'u da
        # çalıştırabilir; if/else bu belirsizliği ortadan kaldırır.
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

      # FIX [YENİ]: GPU host'a döndü, Ollama ROCm ile yeniden başlatılabilir.
      # amdgpu verify'dan sonra kısa bekleme — modül tam yüklenmeden
      # Ollama başlarsa ROCm device'ı bulamaz.
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
    "pcie_aspm=default"
    # FIX [YENİ]: RCU grace period kısaltılır → scheduling latency azalır.
    # BORE kernel ile birlikte çalışır, çakışma yok.
    # NOT: rcu_nocb_poll burada kasıtlı olarak YOK — rcu_nocbs=<cpulist>
    # olmadan noop'tur. Belirli CPU'ları offload etmek istenirse
    # "rcu_nocbs=2-5" gibi bir parametre eklenip ardından rcu_nocb_poll eklenebilir.
    "rcupdate.rcu_expedited=1"
  ];

  # ============================================================
  # Initrd
  # ============================================================
  # amdgpu: initrd'de early KMS (greetd öncesi framebuffer) için gerekli.
  # vfio_pci: initrd'ye ALINMADI — bu kurulumda host amdgpu kullanır,
  #   passthrough dinamiktir (hook ile). initrd'de vfio_pci yüklenirse
  #   GPU'yu boot anında vfio'ya bağlar ve amdgpu hiç çalışamaz.
  # dm_mod: hardware-configuration.nix'teki dm-crypt modülü zaten kapsar.
  boot.initrd.availableKernelModules = [
    "amdgpu"
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ vendor-reset ];
  boot.kernelModules = [ "vendor-reset" ];

  # ============================================================
  # Sysctl
  # ============================================================
  boot.kernel.sysctl = {
    # --- VM ---
    "vm.max_map_count" = 1048576;    # CS2 / Steam zorunlusu
    "vm.nr_hugepages"  = 0;          # VFIO hook script yönetir
    "vm.swappiness"    = 10;         # FIX [YENİ]: zramSwap aktifken RAM baskısı
                                     # olmadan swap'a gitmemesi için düşük değer.
                                     # 10 → fiziksel RAM dolmadan swap kullanılmaz.

    # --- Kernel Scheduler ---
    # FIX [YENİ]: CS2 gibi çok iş parçacıklı oyunlarda autogroup, render/game
    # thread'lerini aynı cgroup'a koyar ve CPU zamanını diğer process'lerle
    # eşit böler. Devre dışı bırakmak oyun thread'lerine doğrudan öncelik verir.
    "kernel.sched_autogroup_enabled" = 0;

    # FIX [YENİ]: AMD Zen3'te split-lock (yanlış hizalanmış atomik işlem)
    # tespiti etkinleştirildiğinde SIGBUS veya performans cezasına yol açar.
    # Wine/Proton bazı Windows binary'leri split-lock üretir; 0 → sadece log.
    "kernel.split_lock_mitigate" = 0;

    # FIX [YENİ]: MangoHud ve GameMode'un donanım performans sayaçlarına
    # (perf_event) root olmadan erişmesi için gerekli.
    # -1 → tüm kullanıcılar perf_event_open() yapabilir.
    "kernel.perf_event_paranoid" = -1;

    # --- Dosya Sistemi ---
    # FIX [YENİ]: VSCode, Brave ve diğer modern uygulamalar çok sayıda dosyayı
    # inotify ile izler. Varsayılan 8192 yetersizdir → "ENOSPC on inotify" hataları.
    "fs.inotify.max_user_watches"   = 524288;
    "fs.inotify.max_user_instances" = 512;

    # --- CPU Zamanlayıcı (ek) ---
    # FIX: Timer interrupt'larını belirli CPU'ya sabitler; CS2 frame time
    # varyansını azaltır. 0 → timer migration kapalı (gaming için önerilir).
    "kernel.timer_migration" = 0;

    # --- VM Dirty ---
    # FIX: Büyük dosya yazımında (VM disk imajı, shader cache) page writeback
    # stall'larının oyun thread'lerini bloke etmesini önler.
    # dirty_background_ratio: arka plan flush başlama eşiği (RAM'in %5'i).
    # dirty_ratio: zorunlu flush eşiği (RAM'in %10'u).
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio"            = 10;

    # --- Ağ ---
    "net.core.rmem_max"        = 16777216;
    "net.core.wmem_max"        = 16777216;
    # FIX [YENİ]: Yüksek paket hızında (CS2 server tickrate) NIC kuyruğu
    # taşmasını önler. Varsayılan 1000 yetersiz.
    "net.core.netdev_max_backlog" = 16384;
    "net.ipv4.tcp_fastopen"    = 3;
  };

  # ============================================================
  # PAM Limitleri
  # FIX [YENİ]: Steam, Wine/Proton ve gamemode çok sayıda dosya tanımlayıcısı
  # açar. Varsayılan 1024 limiti "too many open files" hatasına neden olur.
  # gamemode grubu için nice limiti → gamemode daemon kendi renice'ini uygular
  # ama PAM sınırı bu değere izin vermiyorsa EPERM alır.
  # ============================================================
  security.pam.loginLimits = [
    { domain = "localhost";     item = "nofile";  type = "hard"; value = "1048576"; }
    { domain = "localhost";     item = "nofile";  type = "soft"; value = "1048576"; }
    { domain = "@gamemode"; item = "nice";    type = "-";    value = "-10"; }
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

    NIXOS_OZONE_WL     = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM    = "wayland;xcb";

    XCURSOR_THEME = "plus-cursor";
    XCURSOR_SIZE  = "16";
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
        "default.clock.max-quantum" = 128;  # min ile eşit → tutarlı düşük latency
      };
    };
  };

  # ============================================================
  # USB
  # ============================================================
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
  '';

  # k10temp için kararlı symlink — Waybar'ın hwmon-path sabit yazılmasını önler.
  systemd.services.hwmon-k10temp-link = {
    description = "Stable /run/hwmon-k10temp symlink for k10temp sensor";
    wantedBy    = [ "multi-user.target" ];
    serviceConfig = {
      Type            = "oneshot";
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
  # fstrim.enable=false: discard=async mount seçeneği TRIM'i asenkron işler.
  services.fstrim.enable = false;

  security.sudo.wheelNeedsPassword = true;

  # ============================================================
  # Btrfs
  # ============================================================
  services.btrfs.autoScrub = {
    enable   = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval  = "1d";

    configs = {
      root = {
        SUBVOLUME              = "/";
        ALLOW_USERS = [ "localhost" ];
        TIMELINE_CREATE        = true;
        TIMELINE_CLEANUP       = true;
        TIMELINE_LIMIT_HOURLY  = "10";
        TIMELINE_LIMIT_DAILY   = "7";
        TIMELINE_LIMIT_WEEKLY  = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY  = "0";
        NUMBER_CLEANUP         = true;
        NUMBER_LIMIT           = "50";
        NUMBER_LIMIT_IMPORTANT = "10";
      };

      home = {
        SUBVOLUME              = "/home";
        ALLOW_USERS = [ "localhost" ];
        TIMELINE_CREATE        = true;
        TIMELINE_CLEANUP       = true;
        TIMELINE_LIMIT_HOURLY  = "5";
        TIMELINE_LIMIT_DAILY   = "7";
        TIMELINE_LIMIT_WEEKLY  = "4";
        TIMELINE_LIMIT_MONTHLY = "6";
        TIMELINE_LIMIT_YEARLY  = "0";
        NUMBER_CLEANUP         = true;
        NUMBER_LIMIT           = "30";
        NUMBER_LIMIT_IMPORTANT = "10";
      };
    };
  };

  # ============================================================
  zramSwap = {
    enable    = true;
    algorithm = "zstd";
    # Varsayılan memoryPercent=50: 16GB RAM için ~8GB zram, yeterli.
    # zramSwap varsayılan priority=100; swap partition priority=10 ile
    # RAM dolana kadar zram önce kullanılır, partition yalnızca
    # hibernasyon veya zram dolduğunda devreye girer.
  };

  # ============================================================
  # Kullanıcı
  # ============================================================
  users.users.localhost = {
    isNormalUser = true;
    description = "Local User";
    initialPassword = "nixos";
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
    polkit_gnome ntfs3g exfat gparted

    steam gamemode gamescope mangohud
    lutris heroic protonup-qt wine

    virt-manager looking-glass-client

    btop nvtopPackages.amd fastfetch bibata-cursors

    git zip unzip usbutils p7zip android-tools
    python3 vscode

    brave telegram-desktop discord protonvpn-gui

    qbittorrent

    flatpak gnome-software

    # Btrfs araçları
    btrfs-progs
    compsize
    snapper
  ];

  # ============================================================
  # GameMode
  # FIX [YENİ]: Sadece enable=true yerine tam tuning yapılandırması.
  # ============================================================
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        # renice: oyun process'lerine uygulanacak nice değeri.
        # -10 → yüksek CPU önceliği. gamemode daemon bunu root yetkisiyle uygular.
        renice = -10;

        # ioprio: I/O öncelik sınıfı. 0 = RT (en yüksek).
        # Disk I/O yoğun map/asset yüklemelerinde fark yaratır.
        ioprio = 0;

        # Oyun çalışırken ekran koruyucuyu engelle (hypridle/swayidle).
        inhibit_screensaver = 1;
        softrealtime = "off";   # CPU RT thread'lere dokunmaz, kernel işi
        reaper_freq  = 5;       # Ölü process temizleme sıklığı (saniye)
      };

      gpu = {
        # AMD GPU'yu oyun süresince "high" performans seviyesine zorla.
        # power-profiles-daemon "performance" profili GPU'yu etkilemez;
        # bu ayar doğrudan amdgpu power state'ini değiştirir.
        apply_gpu_optimisations = "accept-responsibility";
        # gpu_device: hangi /dev/dri/cardN kullanılacağı.
        # Doğrulamak için: ls -la /sys/class/drm/card*/device/driver | grep amdgpu
        # Tek GPU sistemde genellikle 0'dır.
        gpu_device              = 0;
        amd_performance_level   = "high";   # auto | low | high | manual
      };

      # FIX: custom start/end notify-send KALDIRILDI.
      # Gamemode daemon, system D-Bus bağlamında çalışır ve kullanıcının
      # Wayland/D-Bus oturumuna erişimi yoktur → notify-send sessizce başarısız olur.
      # Durum göstergesi olarak Waybar'daki "gamemode" modülü yeterlidir;
      # zaten config'de modules-right içinde tanımlı.
    };
  };

  # ============================================================
  # Steam
  # ============================================================
  programs.steam = {
    enable = true;
    # Proton-GE: topluluk Proton build'i — daha iyi Windows oyun uyumluluğu.
    # Steam'de: Ayarlar → Uyumluluk → "Proton-GE-..." seçeneği görünür.
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
    # gamescopeSession: Steam Big Picture'ı doğrudan Gamescope içinde başlatır.
    # Hyprland oturumu olmadan tam ekran gaming session sağlar.
    gamescopeSession.enable = true;
  };

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
      PermitRootLogin        = "no";
      X11Forwarding          = false;
      MaxAuthTries           = 3;
    };
  };

  # ============================================================
  # Nix
  # ============================================================
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
    max-jobs              = "auto";

    # Geliştirme ortamlarında build input'larını ve derivation'ları sakla.
    # keep-outputs    : nix-collect-garbage build artifact'larını silmez.
    # keep-derivations: .drv dosyaları saklanır → nix develop çalışır.
    # NOT: system/nix/nix.conf'taki bu ayarlar buraya taşındı; NixOS
    # nix.settings'ten /etc/nix/nix.conf üretir, standalone dosya çakışırdı.
    keep-outputs      = true;
    keep-derivations  = true;

    # FIX [YENİ]: Dirty (commit edilmemiş değişiklik içeren) flake ile
    # nixos-rebuild çalıştırıldığında uyarıyı bastırır.
    # /etc/nixos git repo'su aktif olarak düzenlendiğinde gürültü yaratır.
    warn-dirty = false;

    substituters = [
      "https://cache.nixos.org"
      "https://xddxdd.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCUSDs="
    ];
  };

  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 30d";
  };

  # Taze 26.05 kurulumu için doğru değer.
  # UYARI: Mevcut sistemi yükseltiyorsan bu satırı değiştirme —
  # kurulumun ilk yapıldığı versiyonu gösterir, stateful servisleri etkiler.
  system.stateVersion = "26.05";

  # AMD RX 6700 XT (Navi 22, gfx1031) ROCm hızlandırması.
  # NOT: nixos-unstable'da acceleration/rocmOverrideGfx kaldırıldı.
  # pkgs.ollama-rocm RX 6700 XT'yi (gfx1031) zaten tanıyor.
  # VFIO hook script GPU geçişi sırasında bu servisi durdurur/başlatır.
  services.ollama = {
    enable  = true;
    package = pkgs.ollama-rocm;
  };

}

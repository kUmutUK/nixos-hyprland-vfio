{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  ################
  # Boot / Kernel
  ################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.gpu_recovery=1"
    "nowatchdog"
    "nmi_watchdog=0"
    "transparent_hugepage=madvise"

    # 🔥 USB power save KAPALI (mouse + keyboard fix)
    "usbcore.autosuspend=-1"
  ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;
  };

  powerManagement.cpuFreqGovernor = "schedutil";

  ################
  # Power (10/10 idle + stability)
  ################
  services.power-profiles-daemon.enable = true;
  powerManagement.powertop.enable = true;

  ################
  # Locale
  ################
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings.LC_ALL = "tr_TR.UTF-8";
  console.keyMap = "trq";

  ################
  # Firewall (KDE CONNECT)
  ################
  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
  };

  ################
  # Graphics (AMD)
  ################
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  environment.variables = {
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "gpl,nggc";
  };

  ################
  # Hyprland
  ################
  programs.hyprland.enable = true;
  programs.hyprland.xwayland.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  ################
  # KDE CONNECT
  ################
  programs.kdeconnect.enable = true;

  ################
  # Waydroid
  ################
  virtualisation.waydroid.enable = true;

  ################
  # Polkit + Disk
  ################
  security.polkit.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  ################
  # Login (greetd)
  ################
  services.xserver.enable = false;
  services.displayManager.sddm.enable = false;

  services.greetd.enable = true;
  services.greetd.settings.default_session = {
    command = "${pkgs.tuigreet}/bin/tuigreet --remember --time --cmd Hyprland";
    user = "greeter";
  };

  ################
  # Audio (Low Latency Stable)
  ################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire."99-lowlatency".context.properties = {
      default.clock.rate = 48000;
      default.clock.quantum = 128;
      default.clock.min-quantum = 64;
      default.clock.max-quantum = 256;
    };
  };

  ################
  # User
  ################
  users.users.localhost = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "storage"
      "gamemode"
    ];
  };

  ################
  # Packages
  ################
  environment.systemPackages = with pkgs; [
    kitty waybar rofi dunst swww grim slurp wl-clipboard
    kdePackages.dolphin
    kdePackages.kdeconnect-kde
    polkit_gnome
    ntfs3g exfat
    steam gamemode gamescope mangohud
    lutris heroic protonup-qt wine
    pavucontrol btop nvtopPackages.amd
    hyprlock hypridle wlogout
    networkmanagerapplet cliphist
    brightnessctl playerctl hyprpicker
    flatpak gparted
    zip unzip usbutils
    brave telegram-desktop android-tools discord protonvpn-gui p7zip
  ];

  ################
  # GameMode
  ################
  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  ################
  # Steam
  ################
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  ################
  # Nix
  ################
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ################
  # Version
  ################
  system.stateVersion = "24.11";
}
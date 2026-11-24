# Template host-specific values: copy next to your host's configuration.nix.
# install.sh rewrites these option defaults for the deployed host instead of
# patching home.nix (see nixos/hosts/nixos/host-settings.nix).
{
  lib,
  ...
}:
{
  options.kumutuk.host = {
    monitorOutput = lib.mkOption {
      type = lib.types.str;
      default = ""; # exact `hyprctl monitors` output name; empty disables live wallpaper
    };
    monitorMode = lib.mkOption {
      type = lib.types.str;
      default = "preferred";
    };
    wallpaperVideo = lib.mkOption {
      type = lib.types.str;
      default = "/home/localhost/Downloads/wallpaper.mp4";
    };
    gitName = lib.mkOption {
      type = lib.types.str;
      default = "changeme";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      default = "you@example.com";
    };
    schedScheduler = lib.mkOption {
      type = lib.types.enum [
        "scx_bpfland"
        "scx_lavd"
        "scx_rusty"
        "scx_flash"
        "scx_p2pq"
        "scx_cake"
      ];
      default = "scx_bpfland";
    };
    nvmeScheduler = lib.mkOption {
      type = lib.types.enum [
        "none"
        "adios"
      ];
      default = "none";
    };
    kernelKcfi = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    usbguardMode = lib.mkOption {
      type = lib.types.enum [
        "audit"
        "enforce"
      ];
      default = "audit";
    };
    # Automatic backups remain disabled until a separate external filesystem is configured.
    vmBackupTarget = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    vmBackupTargetUUID = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    vmBackupSourceDisk = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    vmBackupName = lib.mkOption {
      type = lib.types.str;
      default = "win10";
    };
    vmBackupRetention = lib.mkOption {
      type = lib.types.ints.between 1 52;
      default = 4;
    };
    vmBackupNotificationUser = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
  };
}

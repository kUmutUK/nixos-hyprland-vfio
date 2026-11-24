# Host-specific desktop values.
#
# These values used to live in the `let` block of hosts/nixos/home.nix and
# were rewritten line-by-line by install.sh. They are host/user data, not module
# logic, so they now live in the host directory as NixOS module options. Home
# Manager runs as a NixOS module, and home.nix reads them through osConfig;
# the module options remain declared here instead of being duplicated in HM.
# install.sh rewrites this small structural file instead of patching home.nix.
#
# Reference-host defaults are kept exactly as before:
#  - monitorOutput "DP-3" (reference host; empty string disables live wallpaper)
#  - hyprlandMonitorMode "preferred" (or a fixed mode such as "2560x1440@170")
#  - wallpaperVideo under ~/Downloads (Unit.ConditionPathExists gates the service)
#  - gitName/gitEmail neutral placeholders; replace before committing anything
#  - schedScheduler "scx_bpfland"; the enum values are the sched_ext policies
#    shipped by the scx-loader default `scx.rustscheds` package set, so trying
#    lavd/rusty/flash/p2pq/cake is a one-line change. install.sh does not
#    rewrite this value; `scxctl stop` always falls back to the kernel BORE.
{
  lib,
  ...
}:
{
  options.kumutuk.host = {
    monitorOutput = lib.mkOption {
      type = lib.types.str;
      default = "DP-3";
      description = "Exact Hyprland output name (hyprctl monitors). An empty string disables the mpvpaper live wallpaper.";
    };
    monitorMode = lib.mkOption {
      type = lib.types.str;
      default = "preferred";
      description = ''Hyprland monitor mode: "preferred" or WIDTHxHEIGHT[@HZ].'';
    };
    wallpaperVideo = lib.mkOption {
      type = lib.types.str;
      default = "/home/localhost/Downloads/Sunless-Lost-from-Light-4K.mp4";
      description = "Absolute path of the mpvpaper live-wallpaper video.";
    };
    gitName = lib.mkOption {
      type = lib.types.str;
      default = "changeme";
      description = "Git user.name for the localhost account.";
    };
    gitEmail = lib.mkOption {
      type = lib.types.str;
      default = "you@example.com";
      description = "Git user.email for the localhost account.";
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
      description = "sched_ext policy scx-loader starts by default. All enum values ship in the scx.rustscheds package set the service already installs; scxctl stop returns to the kernel BORE/EEVDF policy.";
    };
    nvmeScheduler = lib.mkOption {
      type = lib.types.enum [
        "none"
        "adios"
      ];
      default = "none";
      description = "NVMe I/O scheduler. ADIOS is compiled into the pinned CachyOS kernel; none remains the reference default until target-host benchmarks justify a change.";
    };
    kernelKcfi = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Opt-in Clang KCFI kernel control-flow integrity. Enabling it changes the kernel derivation and requires a full-system build and boot test.";
    };
    usbguardMode = lib.mkOption {
      type = lib.types.enum [
        "audit"
        "enforce"
      ];
      default = "audit";
      description = "USBGuard policy. Keep audit unless a generated, reviewed rules.conf explicitly allows every required host and VM USB device.";
    };
    vmBackupTarget = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Dedicated external backup mountpoint. Empty disables the automatic VM backup timer.";
    };
    vmBackupTargetUUID = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Expected filesystem UUID of vmBackupTarget; both backup target fields must be set together.";
    };
    vmBackupSourceDisk = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/media/win10new.qcow2";
      description = "Source qcow2 disk to back up after the VM has shut down.";
    };
    vmBackupName = lib.mkOption {
      type = lib.types.str;
      default = "win10";
      description = "Libvirt domain name passed to the fail-closed backup helper.";
    };
    vmBackupRetention = lib.mkOption {
      type = lib.types.ints.between 1 52;
      default = 4;
      description = "Number of verified weekly VM backups to retain on the external disk.";
    };
    vmBackupNotificationUser = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Desktop account that receives best-effort VM backup notifications when logged in.";
    };
  };
}

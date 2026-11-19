# Host-specific desktop values.
#
# These five values used to live in the `let` block of hosts/nixos/home.nix and
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
      default = "/home/localhost/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4";
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
  };
}

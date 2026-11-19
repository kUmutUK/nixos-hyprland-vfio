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
  };
}

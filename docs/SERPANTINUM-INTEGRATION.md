# Optional Serpantinum integration

This project can optionally run [Serpantinum](https://github.com/ilyamiro/serpantinum) as its desktop shell while keeping the existing Hyprland compositor configuration and gaming/VFIO stack.

## Design and safety

- The feature switch lives in `nixos/flake.nix` as `enableSerpantinum = false;` and is **off by default**.
- `serpantinum.inputs.nixpkgs.follows = "nixpkgs"` makes Serpantinum use the same package-set revision as this configuration's Hyprland and companion tools.
- The upstream NixOS module is always imported to declare its option, but its system prerequisites are enabled only when the switch is `true`.
- Home Manager imports the upstream user module only when the switch is enabled. The shell is started by the current Hyprland Lua startup hook, so `programs.serpantinum.systemd.enable` is disabled to avoid duplicate launches.
- When enabled, the startup hook does not launch Waybar or Dunst; Serpantinum supplies the bar, dock, and shell notifications. The existing Rofi `SUPER+A` binding remains, and `SUPER+D` launches Serpantinum's documented `start` view only in this profile. GTK styling, cursor, monitor setup, Hyprland window rules, mpvpaper/Arthur wallpaper watchdog, Vulkan low-latency layer, kernel choice, and Windows VM/VFIO XML remain unchanged.
- Clipboard history uses distinct text and image watchers in Serpantinum mode, as recommended by upstream. The wallpaper picker points at `~/Pictures/Wallpapers`; it does not control or overwrite the existing live-video wallpaper.
- Matugen is disabled and a palette matching the current rose/teal/gold GTK and Hyprland colors is provided. This avoids recoloring the existing setup when the wallpaper changes.

## Prepare the lock file

The code adds a new external flake input. From the repository's `nixos/` directory, run:

```bash
nix flake lock
git diff -- flake.lock
```

Inspect the diff. The lock should add Serpantinum and its wallpaper source while reusing the existing `nixpkgs` node. Do not manually invent `narHash` values. Commit the generated lock with the changed files before relying on the project's CI; the CI intentionally uses `--no-update-lock-file`.

## Enable

1. In `nixos/flake.nix`, set `enableSerpantinum = true;`.
2. From the `nixos/` directory, evaluate and rebuild:

   ```bash
   nix flake check --no-build --show-trace --no-update-lock-file
   sudo nixos-rebuild switch --flake .#nixos
   ```

3. Log in to the Hyprland session. The configured startup hook launches `serpantinumd start`; no external installation script is required.

The Home Manager module creates `~/Pictures/Wallpapers` if it does not exist. Place static images there if you want Serpantinum's wallpaper selector to have content. The existing `wallpaperVideo` setting and mpvpaper watchdog continue to handle the Arthur live wallpaper. The upstream Home Manager module writes its generated settings only when `~/.config/serpantinum/settings.json` does not already exist. If you have previously installed Serpantinum manually and want this declarative palette to apply, back up that file and move it out of the way before activating the profile.

## Validate before adopting permanently

Compare the default profile and Serpantinum profile using the same system generation and workload. Check:

- Hyprland startup, exit, and a fresh login; the bar and notification UI must appear exactly once.
- Rofi `SUPER+A`, Serpantinum Start view `SUPER+D`, existing Hyprland shortcuts, monitor mode/VRR, and GTK cursor/theme.
- Clipboard text and image history, tray icons, audio/volume OSD, and notifications.
- `btop` idle CPU and memory, plus CS2 frametimes / 1% lows at the monitor's target refresh rate.
- Windows VM start and shutdown, host display recovery, and second VM start. The shell change should not alter VFIO behavior, but the normal hardware regression sequence should still be rerun after a system rebuild.

Serpantinum's upstream package is licensed AGPL-3.0-or-later; that dependency's license is separate from the MIT license of this repository. This profile is optional and has not been built or benchmarked in the current editing environment. Nix evaluation, package build, and physical-hardware testing must be performed on a host with Nix and the target hardware.

## Revert

Set `enableSerpantinum = false;` and run `sudo nixos-rebuild switch --flake .#nixos` again. Waybar, Dunst, and the previous clipboard startup command will then be restored by the generated Hyprland Lua configuration. The locked input can remain in `flake.lock` without being activated.

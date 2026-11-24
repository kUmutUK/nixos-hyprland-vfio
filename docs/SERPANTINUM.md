# Serpantinum desktop shell integration

[Serpantinum](https://github.com/ilyamiro/serpantinum) is a Quickshell-based
desktop shell for Wayland compositors (bar, notification daemon, app launcher,
clipboard history overlay, system panel, wallpaper picker, optional dock,
PipeWire audio engine, and a gamma/blue-light daemon). This configuration
imports it as a Flake input and runs it as the Hyprland shell, replacing the
previous Waybar + Dunst + Rofi + `nm-applet` session stack.

Upstream documentation: [serpantinum.dev](https://serpantinum.dev) —
installation and Nix module reference, the
[Hyprland compositor guide](https://serpantinum.dev/configure/compositors/hyprland),
and the settings reference. Upstream is licensed AGPL-3.0; this repository
only consumes it as a pinned input and remains under its own license.

## What changed and what did not

| Session component | Before | Now |
|---|---|---|
| Bar | Waybar (autostart from `hyprland.lua`) | Serpantinum bar (`systemd --user` service) |
| Notifications | Dunst (autostart) | Serpantinum notification daemon; `notify-send` callers (`gamemode-notify`, translate scripts, mpvpaper watchdog) keep working unmodified |
| App launcher | Rofi (`SUPER+A`) | Serpantinum launcher overlay |
| Clipboard picker | Rofi + cliphist (`SUPER+B`) | Serpantinum clipboard overlay, same cliphist history |
| Network tray | `nm-applet` (autostart) | Serpantinum bar `wifi` module + network panel |
| Volume keys | `wpctl` binds | `serpantinum volume …` CLI (drives the same PipeWire defaults, keeps the bar in sync) |
| Lock screen | Hyprlock | **Unchanged** — Hyprlock stays the lock authority |
| Idle handling | hypridle | **Unchanged** — hypridle stays the single idle authority; the shell's own idle scheduler is disabled to avoid double lock/dpms/suspend |
| Live wallpaper | mpvpaper + watchdog | **Unchanged** — mpvpaper keeps owning the video wallpaper layer; the shell's wallpaper picker manages still images and Matugen theming |
| Scratchpads | Pyprland | **Unchanged** |
| Screenshots | `grim`/`slurp`/`satty` binds | **Unchanged**; bare `Print` additionally opens the Serpantinum screenshot editor |
| Waybar AMD-GPU telemetry | Waybar custom module | Not carried into the bar (the sysmon module covers cpu/ram/temp); the script, `scripts/waybar-amdgpu.sh`, its tests, and manual Waybar fallback all remain |
| System-panel power actions | `wlogout` button in Waybar | Serpantinum system panel (`SUPER+I`); `wlogout` stays installed |

Waybar, Rofi, Dunst, and `wlogout` remain installed in the system profile on
purpose. They are simply no longer autostarted, so they act as a manual
fallback session: in a terminal run `waybar`, `dunst`, and `rofi -show drun`
to get the previous stack back for comparison or recovery.

## How it is wired

- `nixos/flake.nix`: `serpantinum.url = "github:ilyamiro/serpantinum"` (its
  own Nixpkgs pin is intentionally **not** followed; the shell builds against
  the Quickshell/Qt revision upstream tests). `serpantinum.nixosModules.default`
  is added to `nixosSystem.modules`, and the input is passed to `home.nix`
  through `home-manager.extraSpecialArgs`.
- `nixos/hosts/nixos/configuration.nix`: `programs.serpantinum.enable = true;`
  — system prerequisites only (the PAM service for the shell's own lock
  screen, Ski as the default file manager, and `mkDefault` fallbacks for
  NetworkManager, Bluetooth, i2c, PipeWire, rtkit, power-profiles-daemon, and
  `nerd-fonts.iosevka`). Every existing explicit setting in this repository
  wins over the module's `mkDefault` values.
- `nixos/hosts/nixos/home.nix`: imports `serpantinum.homeManagerModules.default`
  and configures `programs.serpantinum` — `systemd.enable = true` runs
  `serpantinumd start` as a user service bound to `graphical-session.target`
  (uwsm brings the target up), so the shell restarts on failure and stops with
  the session instead of being an unmanaged `exec-once`.
- `hyprland.lua` (generated from `home.nix`): the autostart block no longer
  execs `waybar`, `dunst`, or `nm-applet`; the `wl-paste --watch cliphist store`
  watcher became the dual text/image watchers Serpantinum itself deploys.

A standalone `home-manager switch` (no NixOS Flake in scope) keeps working:
`serpantinum` stays `null`, the module is not imported, and the previous
Waybar/Dunst session can be started manually from the still-installed
packages.

## Keybind map

Existing window/focus/resize/scratchpad binds are untouched. Changed or new:

| Shortcut | Action | Note |
|---|---|---|
| `SUPER+A` | Launcher overlay | previously Rofi `drun` |
| `SUPER+B` | Clipboard overlay | previously the Rofi cliphist picker; same `cliphist` history |
| `SUPER+M` / `N` / `W` | Music / network / wallpaper overlays | new |
| `SUPER+O` / `I` / `U` / `T` | Calendar / system panel / volume slider / keybind cheat sheet | new |
| `SUPER+SHIFT+B` | Bar autohide | new |
| `Print` | Screenshot region into the shell's editor | new; `SUPER+P`/`SUPER+SHIFT+P` (grim/satty) unchanged |
| `SUPER+1…0` | `serpantinum msg workspace N` | routed through the shell so bar indicators update immediately |
| `SUPER+SHIFT+1…0` | Silent window move to workspace | kept as the previous `follow = false` dispatch; upstream's `msg workspace N move` maps to `movetoworkspace`, which would pull focus along |
| `XF86Audio*` | `serpantinum volume …` CLI | same PipeWire sinks the `wpctl` binds used |

Upstream's default overlay binds (`SUPER+C/D/V/H/B/F…`) collide with this
configuration's terminal, float, focus, and scratchpad binds, so the overlays
were re-mapped onto free keys as listed above.

## Settings model

`programs.serpantinum.settings` mirrors the shell's `settings.json` one to
one; only entries that differ from upstream defaults are declared in
`home.nix`:

- `general.language = "tr"` — the shell ships a full Turkish translation
  (`assets/languages/tr.json`), matching the `tr` keyboard layout and this
  repository's documentation language.
- `general.location` — Istanbul coordinates, mirroring the (currently
  disabled) `services.wlsunset` values, used by the weather module.
- `bar.modules` — the closest mapping of the previous Waybar layout:
  workspaces + media left, clock + weather centered, tray with kb/wifi/vol
  and sysmon clusters right.
- `theme.fontFamily = "JetBrainsMono Nerd Font"` and `matugen = true` —
  keeps the font used by Kitty/GTK/Rofi and enables Material You color
  generation from the current wallpaper (same idea as the manual `wal -i`
  pywal workflow, which also remains available).
- `notifications.dnd = false` — Dunst showed every notification; the
  upstream template's do-not-disturb default is rejected.
- `idle.enabled = false` — hypridle remains authoritative (see the table).
- `dock.enabled = false` — the dock starts off; enable it from the shell's
  settings UI or here after checking it against the gaming window rules.

The Home Manager module only writes `~/.config/serpantinum/settings.json` on
first activation (it never overwrites an existing file), and the declared
Nix settings are layered on top of upstream's bundled defaults. Editing
settings from the shell's own UI therefore works and is not fought by
rebuilds; to pin a value permanently, promote it into
`programs.serpantinum.settings` in `home.nix` and remove the generated file.

## Updating and pinning

The lock pins a single commit of `serpantinum` plus its nested inputs
(its own `nixpkgs`, `Ski`, and `shell-wallpapers`). Update deliberately:

```bash
cd nixos
nix flake update serpantinum
nix flake check --no-build
sudo nixos-rebuild switch --flake .#nixos
```

The shell's package builds Quickshell and Qt from its own pinned Nixpkgs, so
the first build after an update is expensive even when the host userland is
cached. Treat a `serpantinum` update like any other input change: Normal CI
(`nix flake check --no-build`) evaluates it, and the manual full-system build
gate applies before release, exactly as for the kernel inputs.

## Verification status

- `nix flake check --no-build` passes with the Serpantinum modules evaluated
  as part of `nixosConfigurations.nixos` (module wiring, Home Manager option
  types, generated Lua syntax).
- The `narHash` of the locked Serpantinum revision was cross-checked with an
  independent NAR-serialization implementation during the integration.
- Not yet covered: a full system build of the shell closure on the target
  host, and runtime validation of the session (bar, overlays, notification
  routing) after `nixos-rebuild switch`. Run the manual full-system build
  before merging this into a release line, as with any runtime-affecting
  change in this repository.

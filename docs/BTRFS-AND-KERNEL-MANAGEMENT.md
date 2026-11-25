# Btrfs and kernel management

This reference configuration uses NixOS-managed Snapper/Btrfs services and a Flake-selected CachyOS kernel. Prefer the declared NixOS interfaces over tools that expect an Arch package manager.

## Btrfs Assistant 2.3.x

The currently locked root Nixpkgs revision provides Btrfs Assistant 2.3.2. Use its privileged launcher for the full GUI:

```bash
btrfs-assistant-launcher
```

The launcher uses the package's Polkit/pkexec policy to start its privileged GUI path. The plain `btrfs-assistant` entry point can run the UI as the ordinary desktop user. On the reference host, that mode produced:

```text
Failed to iterate over the subvolumes of "/" : Could not search B-tree
ERROR: can't perform the search: Operation not permitted
```

The same read-only `btrfs subvolume list -t /` operation failed as the unprivileged user and succeeded under `sudo`, listing the existing root, home, snapshots, and other subvolumes. This indicates a permission boundary for that operation; it does not by itself indicate Btrfs corruption. The Home Manager Fish alias maps `btrfs-assistant` to `btrfs-assistant-launcher`, so the normal terminal command uses the intended 2.3.x authorization path. Run the GUI as your desktop user and let Polkit request authorization; do not start the GUI with `sudo`.

### Hyprland Polkit authentication agent

The graphical authentication agent is a separate user-session service. It must be running for Polkit dialogs to be presented in Hyprland. The reference host's diagnostic log showed `No session for cookie` while `hyprpolkitagent` was absent from the process list. That means the graphical session had no registered Polkit agent when Btrfs Assistant invoked pkexec.

The Nixpkgs `hyprpolkitagent` package installs its executable at `$out/libexec/hyprpolkitagent`, not `$out/bin/hyprpolkitagent`. Home Manager defines `hyprpolkitagent.service` with that exact store path and enables it for `graphical-session.target`. Serpantinum is started by systemd/uwsm on that same target, so the graphical authentication agent starts with the desktop session and stops when the session ends. The Hyprland startup callback also imports `WAYLAND_DISPLAY` and the D-Bus activation environment, then restarts the agent to cover any environment-import race.

After rebuilding and logging into Hyprland, verify the service before opening Btrfs Assistant:

```bash
systemctl --user status hyprpolkitagent.service --no-pager
journalctl --user -b -u hyprpolkitagent.service --no-pager
```

The expected state is `active (running)`. Then start `btrfs-assistant-launcher` from the desktop user session; Polkit should present the graphical authorization dialog.

The host already enables `security.polkit`, configures Snapper's `root` and `home` profiles, and enables Snapper timeline/cleanup timers. Keep scheduling declarative: `services.btrfs.autoScrub` and `services.snapper` own automatic maintenance and snapshot cadence. Do not enable Btrfs Assistant's traditional-distro cron scheduling on top of those services.

### Why this guide does not force 3.0.0

Upstream Btrfs Assistant 3.0.0 (14 October 2026) changes the package architecture: the GUI becomes rootless and privileged filesystem operations move to a separate D-Bus-activated helper. The upstream changelog explicitly says packaging and operation are affected. The currently locked Nixpkgs package remains 2.3.2. A safe NixOS upgrade therefore needs to package and wire the 3.0.0 helper executable, D-Bus service and system-bus policy, systemd helper unit, and Polkit action together. Merely overriding the version or source hash would leave the authorization architecture incomplete. Keep 2.3.2 and use its launcher until the complete 3.0.0 integration is built and tested.

## CachyOS kernel management on NixOS

Kernel selection remains declarative in `nixos/flake.nix`:

```nix
boot.kernelPackages = rtBoreLtoV3KernelPackagesFor config.kumutuk.host.kernelKcfi;
```

The repository now includes a **native Qt 6 NixOS Kernel Manager desktop app**, using the same standalone-window approach as the LSFG-VK and MAKO applications. It has a sidebar and dedicated Kernel catalogue, Boot entries, Kernel configuration, and Kernel actions pages. Its dark palette uses a CachyOS-inspired blue accent. Launch it from the application menu (**NixOS Kernel Manager**) or run:

```bash
nixos-kernel-manager
```

It reports the running kernel, Flake-declared kernel profile, evaluated kernel version, locked `cachyos-kernel` revision, systemd-boot entries, and NixOS system generations. Inspection remains read-only. Kernel actions are separated: updating only the `cachyos-kernel` input in `flake.lock`, building only the selected kernel without activation, or running an explicit full-system `nixos-rebuild switch`. Each action has a Qt confirmation dialog and Kitty shows the complete command output. The lock update and system switch run through a fixed, immutable Polkit helper via `pkexec`; the build stays unprivileged. The system switch invokes the Hyprland Polkit agent for graphical authentication, not a terminal sudo prompt.

**Safety boundaries:**

- Kernel selection remains in the Flake; the manager does not install Arch/AUR packages, write boot entries, or edit `boot.kernelPackages`.
- Updating changes only the CachyOS Flake lock entry through the restricted Polkit helper. It does not build or activate a kernel.
- Kernel-only build runs as the desktop user through the Nix daemon; it does not request administrator authorization or switch the running system.
- Full-system rebuild is a separate, explicit activation through the restricted `pkexec` helper and the graphical Polkit agent. It does not update the lock file.
- The helper accepts only the two supported operations (CachyOS lock-input update and the configured `#nixos` system switch); it does not provide a root shell, arbitrary command execution, or passwordless sudo.
- The manager reflects the current Flake. It does not offer an LTS choice because the old LTS specialisation has been removed from the current configuration.

The existing Fish aliases remain available: `nup` updates the pinned CachyOS Flake input and lock metadata only; **it does not activate the new kernel**. `nrs` builds and activates the currently declared system. The manager is a NixOS front-end, not a port of the CachyOS Kernel Manager.

## Read-only checks

These commands inspect the current state without changing the filesystem or boot configuration:

```bash
# Confirm the active kernel release.
uname -r

# Confirm the installed Snapper configurations.
sudo snapper list-configs

# Confirm Btrfs subvolume visibility with the privileges required by btrfs-progs.
sudo btrfs subvolume list -t /

# Confirm the authorization and snapshot timers.
systemctl is-active polkit.service snapper-timeline.timer snapper-cleanup.timer
```

A successful read-only listing is not a substitute for testing Btrfs Assistant's GUI actions. Do not test delete, restore, balance, or scrub actions merely to validate the application; keep GUI verification to opening the app, reading the Overview/Subvolumes/Snapper views, and confirming that the two Snapper profiles appear.

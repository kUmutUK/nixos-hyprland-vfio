# Btrfs and kernel management

This reference configuration uses NixOS-managed Snapper/Btrfs services and a Flake-selected CachyOS kernel. Prefer the declared NixOS interfaces over tools that expect an Arch package manager.

## Btrfs Assistant 2.3.x

The currently locked root Nixpkgs revision provides Btrfs Assistant 2.3.2. In the 2.3.x packaging model, use the privileged launcher for the full GUI:

```bash
btrfs-assistant-launcher
```

The launcher uses the package's Polkit/pkexec policy to start its privileged GUI path. The plain `btrfs-assistant` entry point can run the UI as the ordinary desktop user. On the reference host, that mode produced:

```text
Failed to iterate over the subvolumes of "/" : Could not search B-tree
ERROR: can't perform the search: Operation not permitted
```

The same read-only `btrfs subvolume list -t /` operation failed as the unprivileged user and succeeded under `sudo`, listing the existing root, home, snapshots, and other subvolumes. This indicates a permission boundary for that operation; it does not by itself indicate Btrfs corruption. The Home Manager Fish alias maps `btrfs-assistant` to `btrfs-assistant-launcher` so the ordinary terminal command follows the intended 2.3.x authorization path. Run the GUI as your desktop user and let Polkit request authorization; do not start the GUI with `sudo`.

The host already enables `security.polkit`, configures Snapper's `root` and `home` profiles, and enables Snapper timeline/cleanup timers. Keep scheduling declarative: `services.btrfs.autoScrub` and `services.snapper` own automatic maintenance and snapshot cadence. Do not enable Btrfs Assistant's traditional-distro cron scheduling on top of those services.

### Why this guide does not force 3.0.0

Upstream Btrfs Assistant 3.0.0 (14 October 2026) changes the package architecture: the GUI becomes rootless and privileged filesystem operations move to a separate D-Bus-activated helper. The upstream changelog explicitly says packaging and operation are affected. The currently locked Nixpkgs package remains 2.3.2. A safe NixOS upgrade therefore needs to package and wire the 3.0.0 helper executable, D-Bus service and system-bus policy, systemd helper unit, and Polkit action together. Merely overriding the version or source hash would leave the authorization architecture incomplete. Keep 2.3.2 and use its launcher until the complete 3.0.0 integration is built and tested.

## CachyOS kernel management on NixOS

CachyOS Kernel Manager is not the control plane for this system. The installed OS is NixOS, and kernel selection is declared in `nixos/flake.nix` through:

```nix
boot.kernelPackages = rtBoreLtoV3KernelPackages;
```

Use the existing Fish aliases:

- `nup` runs `sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel`. It updates the pinned CachyOS kernel Flake input and lock metadata only; **it does not activate the new kernel**.
- `nrs` runs `sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos`. This evaluates, builds or substitutes, and activates the declared system generation. Treat this as a separate, intentional step after reviewing the lock diff and build result.

Do not install an Arch/AUR kernel manager into the NixOS system or edit the active kernel outside the Flake. Keep the primary RT-Bore-LTO kernel choice, CPU-target setting, module compatibility helper, and input lock intentional and reviewable.

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

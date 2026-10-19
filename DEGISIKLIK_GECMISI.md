# Historical Change Log Index (English)

This legacy filename now contains an English current-state summary so older links remain useful. The maintained and current change log is [`CHANGELOG.md`](CHANGELOG.md).

## Current configuration notes — 2026-10-19

- The active kernel package is `linuxPackages-cachyos-rt-bore-lto` from the CachyOS upstream `master` input. The kernel version is not hard-coded in `nixos/flake.nix`; `nixos/flake.lock` records the resolved revision for reproducibility. To advance the CachyOS input, use `sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel`, inspect the lock diff, and validate the resulting build. The RT-Bore-LTO LTO package is not published in the upstream binary cache, so a local build is expected. The previously reported successful target test used standard BORE-LTO and does not validate RT-Bore-LTO.
- The system uses `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1` by default. Incompatible games can opt out with `DISABLE_LOW_LATENCY_LAYER=1 %command%`. The upstream `low_latency_layer` v0.2.0 release also documents an incompatibility with `obs_vkcapture`.
- The installer checks `/etc/nixos/hashedPassword` presence, non-empty content, `root:root` ownership, and mode `0600`; if invalid, it warns so the documented manual step can repair the file before activation.
- `install.sh` updates the QEMU hook source under `/etc/nixos/nixos/hooks/qemu`. The active NixOS-generated libvirt hook is refreshed only after a successful `nixos-rebuild switch`. The installer writes the VM XML but does not automatically run `virsh define`. Existing VM XML is backed up and retained as the source of truth; only its two GPU/audio PCI source addresses are synchronized.
- Installer backups are retained and are not pruned automatically. Fail2ban permits loopback without banning but private LAN ranges remain subject to the ban policy. SSH is enabled on TCP 22 for the configured non-root user while root login remains disabled.
- The historical note under release `[1.3.6]` about `amd_iommu=on` is not the current state. The active configuration does not add `amd_iommu=on` or `iommu=pt`; enable IOMMU/AMD-Vi in firmware and verify it at runtime.

## Original detailed historical record

The complete original Turkish release history has been preserved unchanged at [`docs/archive/DEGISIKLIK_GECMISI.md`](docs/archive/DEGISIKLIK_GECMISI.md). It is an archival source, not the current configuration reference. For current and maintained entries, use [`CHANGELOG.md`](CHANGELOG.md).

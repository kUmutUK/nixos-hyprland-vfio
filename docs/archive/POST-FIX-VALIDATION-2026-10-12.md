# Post-fix validation checklist — 2026-10-12 snapshot

This historical checklist separates source-level checks from actions requiring the target NixOS host. Its live-system steps were not run during that review.

## Source-level checks recorded at the time

- `install.sh` executable mode should be `100755`.
- PCI parsing and hostdev synchronization should reject incomplete or malformed addresses.
- The deployed QEMU XML should be checked against the PCI addresses in the hook.
- The installer should preserve machine-specific hardware configuration and state-version values.
- The `system.stateVersion` and `home.stateVersion` values should not be guessed if they cannot be found.

## Required target-host checks

1. Run `nix flake check --no-build --show-trace` and the normal NixOS build on the target machine.
2. Verify the exact OVMF NVRAM template path provided by the installed libvirt/QEMU packages.
3. Confirm `hardware-configuration.nix` contains UUIDs and mount points for the actual disks.
4. Inspect `swtpm` state-directory ownership after libvirt starts.
5. Test VM start, clean guest shutdown, host driver restoration, display/session restoration, and a second VM start.

This list is historical and should be reconciled with `docs/REPAIR-AND-VALIDATION-REPORT.md`.

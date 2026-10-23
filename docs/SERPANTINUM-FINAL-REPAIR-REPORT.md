# Serpantinum Integration & CI Repair Report

**Project:** NixOS / Hyprland / AMD gaming configuration with VFIO  
**Reviewed against:** uploaded CI logs `logs_108477678833.zip` and the previously delivered integrated source archive  
**Target hardware profile:** Ryzen 5 5600, Radeon RX 6700 XT, 32 GB RAM  
**Date:** 2026-10-23

## Executive summary

The uploaded GitHub Actions logs showed a real, blocking failure in the required ShellCheck step for the Nix-generated VFIO hook. The build used `--no-update-lock-file`, while the committed flake lock did not yet contain all Nix-computed metadata for the newly added Serpantinum dependency. Nix therefore stopped before it could build the generated hook.

The repair now pins Serpantinum to the exact immutable upstream revision observed in the log (`e0c1d79375bc7adfd01fecb8a4e319d521df1ea9`), records its direct and wallpaper dependency nodes in `nixos/flake.lock`, and adds a CI bootstrap step to let Nix derive the pinned source's `narHash`/`lastModified` rather than inventing them. Read-only `nix build` / `nix flake check` steps run after that metadata resolution. The final lock drift guard allows only those two computed Serpantinum metadata fields; other changes remain a hard failure.

The environment used for this repair does not have the Nix CLI, ShellCheck, nixfmt, or `virt-xml-validate` installed and cannot reach GitHub directly. Therefore this report does **not** claim a completed NixOS evaluation, generated-hook build, ShellCheck execution, or live libvirt validation. The log's lock-update blocker is addressed in the workflow, but a GitHub Actions run or a Nix-enabled host is still required to prove the upstream hash resolution and full evaluation succeed.

## Changes made

### Lock-file and CI failure

- Pinned the `serpantinum` flake URL in `nixos/flake.nix` to the reviewed immutable commit.
- Added root lock graph wiring for Serpantinum and its non-flake `shell-wallpapers` dependency.
- Added `scripts/test-flake-lock.py` to validate the lock graph, pin, `nixpkgs.follows`, transitive wallpaper input, and the CI steps that resolve computed metadata before any `--no-update-lock-file` build.
- Added a CI step to run `nix flake lock` from `nixos/` before read-only Nix checks. This hydrates hash metadata from the immutable source; it does not intentionally update the other already-locked flake inputs.
- Replaced the overly strict “lock file must never change” guard with a narrower guard. The only expected CI-time delta is the Nix-computed `narHash` and `lastModified` for the Serpantinum source. Any additional lock drift fails CI.
- Updated the existing installer invariant test to expect the immutable Serpantinum URL.

### Desktop integration and compatibility

- Added `scripts/serpantinum-wallpaper-picker` and installed it through Home Manager. The `Super+W` picker pauses the optional `mpvpaper` service/watchdog for the current session before opening the static picker, avoiding overlapping wallpaper surfaces. The existing live wallpaper returns through its normal graphical-session startup on the next login when enabled.
- Kept clipboard text/image listeners, the existing Hyprland workspace controls, game/VFIO behavior and `hypridle` ownership intact.
- Disabled the airplane-mode OSD on this desktop-oriented Ryzen/Radeon configuration.
- Retained the desktop-appropriate choices: no battery widget, no background weather/location lookups, no second Waybar/Dunst/network applet stack, and no automatic EasyEffects service that could add an unnecessary audio-processing layer to a latency-sensitive gaming setup.
- Updated README, installation and contributor instructions with the lock-resolution and targeted-build sequence.
- Fixed the embedded-script extractor so a `home.file` declaration that references a script source does not make it accidentally count the next inline script twice.

## Verification performed in this environment

All following checks passed locally:

- `scripts/test-flake-lock.py`: pinned root/child nodes and graph edges; CI metadata-resolution ordering and drift guard.
- `python3 -m json.tool nixos/flake.lock`: valid JSON.
- Python AST parsing for all repository Python files.
- `.github/workflows/check.yml`: parsed successfully as YAML and contains the expected lock-resolution/drift-guard steps.
- `scripts/test-vm-xml.py`: XML well-formedness, machine/boot invariants, USB passthrough entries, two unique PCI host devices and PCI targets matching the QEMU hook.
- `scripts/test-vm-xml-sync.py`: synchronization invariants, identity/custom-setting preservation, backups and fail-closed handling.
- `scripts/test-vm-diagnostic.py`: valid video-device insertion and rejection of duplicate/mixed/invalid XML without modifying production XML.
- `scripts/test-installer-invariants.sh`: all installer, NixOS/VFIO, locale/UI, updateable RT-Bore-LTO and migration invariants.
- `scripts/test-installer-rollback.sh`: rollback coverage for files, active/dangling symlinks and snapshot/directory safety.
- `scripts/test-vfio-hook-driver-state.sh`: mocked VFIO driver-state and pre-VM service-state regressions.
- `bash -n` for source Bash scripts and QEMU hook.
- `scripts/extract-embedded-scripts.py`: found exactly seven embedded scripts; all seven passed `bash -n`.
- Representative Serpantinum keybindings (`Super+O`, `Super+W`, screenshot and record/QR combinations): each appears once in the explicit binding set.

## Checks not run here

- `nix flake lock` on the pinned source: Nix is not installed and network resolution is unavailable in this environment.
- `nix flake check --no-build --show-trace --no-update-lock-file`.
- Build and ShellCheck of `.#nixosConfigurations.nixos.config.virtualisation.libvirtd.hooks.qemu.vfio`.
- `shellcheck` on source and extracted scripts.
- `virt-xml-validate`, live libvirt domain validation and a Windows VM boot/shutdown test.
- Target-machine tests for the Radeon display and GPU passthrough lifecycle.

## Recommended final verification on a Nix-enabled host

From the repository root:

```bash
python3 scripts/test-flake-lock.py
(cd nixos && nix flake lock)
git diff -- nixos/flake.lock
(cd nixos && nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false)
(cd nixos && nix build --no-link --no-update-lock-file --print-out-paths \
  .#nixosConfigurations.nixos.config.virtualisation.libvirtd.hooks.qemu.vfio)
```

Inspect the lock diff and commit the hash metadata produced by Nix if it is the expected Serpantinum metadata only. Then run the CI workflow. Separately validate the VM XML on the target host and arrange a TTY/SSH recovery path before any real VFIO lifecycle test; static tests are not a substitute for real hardware validation.

## References

- Serpantinum upstream repository and NixOS module instructions: <https://github.com/ilyamiro/serpantinum> and <https://serpantinum.dev/installation/nixos/>
- Serpantinum option reference (used to compare the current settings names): <https://serpantinum.dev/configure/>

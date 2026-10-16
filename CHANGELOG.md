# Changelog

This file summarizes notable changes in English. The original detailed Turkish history is preserved in [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md).

## Unreleased — 2026-10-16

### Changed
- Switched the selected kernel from standard CachyOS BORE-LTO to `linuxPackages-cachyos-rt-bore-lto`. Upstream lists RT-Bore-LTO LTO builds as uncached, so the kernel is expected to compile locally. The previous successful target-system test used standard BORE-LTO and does not validate this new kernel; boot and VFIO lifecycle tests are still required.
- Superseded the earlier system-wide low-latency/Reflex environment variables. The implicit Vulkan layer is disabled globally using `DISABLE_LOW_LATENCY_LAYER=1`; opt in per game with a Steam launch option, and use `LOW_LATENCY_LAYER_REFLEX=1` only when testing the Reflex interface.

### Fixed
- Reject running the installer from `/etc/nixos` before system changes, trim monitor-name input before using it in Hyprland defaults, and abort VM XML synchronization unless exactly two real PCI `hostdev` elements have supported source-address blocks. Added regression coverage for malformed/incomplete/extra PCI pairs and whitespace-only monitor input.
- Corrected the Rofi theme comment without changing the working `arthur` binding; clarified that `wuwa-gemma` is a custom Ollama alias based on Aya Expanse 8B, not a Gemma-family model.
- Restricted installer XML address synchronization to PCI `hostdev` nodes, fixed warnings for incomplete versus extra PCI entries, and added a regression test that ensures USB address sources are never rewritten as PCI addresses.
- Aligned the README with the default VM XML: it documents the two active fixed USB passthrough IDs. The former system-wide low-latency-layer/Reflex configuration has since been superseded; the current setup disables the implicit layer globally and opts in per game.
- Clarified that installer host-device counts and synchronization refer to PCI `hostdev` entries, not all device types; extended the VM XML regression test to guard the documented USB IDs as well as the PCI pair.
- Clarified single-GPU recovery guidance: the hook can terminate SSH sessions for the default `localhost` user, so the README and Turkish setup guide now require a physical recovery TTY unless a separate, tested administrative session is configured. Removed a duplicate `android-file-transfer` package entry and corrected a stale Home Manager package-list comment.
- Removed the unused Waypaper package and `SUPER+W` binding, corrected the installer's missing-PCI-device diagnostic so it does not invoke `lspci` a second time, and translated the color notification title to English.
- Clarified that IOMMU kernel parameters are not enabled by default, corrected the VM input limitation comment, and added a regression check that VM XML GPU/audio PCI addresses match the QEMU hook defaults.
- Standardized root-required commands in the fresh-install guides and preserved the generated NixOS config as a backup before installing the repository tree.
- Fixed the Home Manager startup command so it starts `mpvpaper-watchdog` only when the optional `monitorOutput` is configured; documented the disabled-by-default kernel parameters and correct per-activation swap encryption behavior.
- Removed stale advice to refresh the CachyOS lock for every install and corrected the English changelog's claim about historical version coverage.
- Changed the CachyOS kernel input to the upstream `release` branch and selected `overlays.pinned` to match the upstream binary-cache nixpkgs revision. Added the upstream Attic cache and public key to the flake and system Nix settings.
- Corrected the Windows VM's Q35 machine alias and made the Windows installation ISO boot ahead of the VirtIO driver ISO. Added a regression test for these XML invariants and wired it into CI.
- Hardened the Ollama fallback translator: HTTP errors, malformed responses, and empty translations now fail without being cached as successful translations.
- Translated English-named project documentation, installer comments/messages, and VFIO hook diagnostics/recovery messages into English. Kept `KURULUM.md` and `DEGISIKLIK_GECMISI.md` in Turkish, while translating comments embedded in installation command examples. Turkish OCR translation notifications remain intentional application UI.
- Replaced stale archive-document wording with English historical summaries so that `docs/` is consistently English and old audit findings are not mistaken for current defects.
- Corrected migration instructions for the required `hashedPassword` file and the VM XML fallback source; updated the related regression test, and guarded against the old undeclared IOMMU path variable recurring. Retracted the false OVMF template mismatch claim, marked old commit hashes as historical, and removed stale guidance to refresh the pinned CachyOS lock for routine installs. The input ZIP did not encode the executable bit for `install.sh`; this follow-up fix bundle restores Unix mode `100755`.
- Fixed the installer preflight text so it accurately describes configuration replacement, VM XML writes, backup retention, and other system changes; corrected the README's Nix formatting command to format each `.nix` file explicitly.
- Made the password-hash checklist preserve existing valid hashes, aligned the Turkish install guide's root-password command with the post-install stage, and translated the last Turkish comment in active Nix code. The repair bundle encodes `install.sh` as executable in the ZIP itself.
- Hardened the VM XML regression test to require exactly two distinct PCI hostdev addresses matching the QEMU hook, and clarified hook recovery logging when GPU display and GPU audio driver restoration differ.
- Corrected disk-size units in `KURULUM.md` and `README.md` (the `sgdisk` `G` suffix means GiB), added whole-disk, mounted-volume, and minimum-capacity checks before the destructive partition-table wipe, and narrowed the documented GPU target to RX 6700 XT/Navi 22. The fix-only patch ZIP stores `install.sh` with Unix mode `100755`; the originally uploaded full-project ZIP did not preserve that mode.

### Validation
- Bash syntax checks passed for the installer, QEMU hook, and VFIO regression test.
- Python compilation checks passed for the scripts.
- VM XML invariants test passed.
- VFIO driver-state / rollback regression test passed.
- The project owner reported that GitHub Actions CI was green and the previous standard BORE-LTO kernel built successfully on the tested target system: the Windows VM started and the host display/Hyprland session returned after normal VM shutdown. This result predates the RT-Bore-LTO switch and does not validate the newly selected uncached RT/LTO kernel. This is owner-reported hardware validation, not independent reproduction by the reviewer and not a compatibility guarantee for other hardware. The review environment lacked Nix and libvirt/QEMU tools, so independent evaluation/build and semantic validation were not performed. The checked-in `flake.lock` pins the CachyOS `release` input; do not refresh it just to apply these fixes. The selected RT-Bore-LTO LTO variant is not published in the upstream binary cache and therefore requires a local build.

## Historical releases

The detailed Turkish changelog is preserved in [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md). This English index intentionally avoids restating historical claims as if they were re-tested against the current tree; consult the Turkish file for the release entries it actually contains.

# Changelog

This file summarizes notable changes in English. The original detailed Turkish history is preserved in [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md).

## Unreleased — 2026-10-19

### Changed
- Switched the selected kernel from standard CachyOS BORE-LTO to `linuxPackages-cachyos-rt-bore-lto`. The version is not hard-coded: the flake follows the upstream `master` branch and the lock can be updated for newer upstream revisions with `nix flake update cachyos-kernel`. Upstream does not cache the RT-Bore-LTO LTO build, so it is expected to compile locally. The prior successful target-system test used standard BORE-LTO and does not validate this new kernel.
- Enabled the Vulkan low-latency layer and Reflex system-wide through PAM session variables `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1`. Applications with compatibility issues can opt out with `DISABLE_LOW_LATENCY_LAYER=1` in their Steam launch options.
- Enabled password SSH for the `localhost` user on TCP 22 while keeping root SSH login disabled, restricting allowed users, and applying Fail2ban to private LAN sources too. Updated the VFIO hook to terminate only the local `seat0` sessions so remote SSH sessions are not killed by `loginctl terminate-user`; a busy GPU still triggers the existing fail-closed handoff check.
- The checked-in CachyOS lock resolves the upstream `master` input to `873c5a2a40575b880a962aaade19afbb572adf92` (reported as Linux 7.2.9) and its matching pinned nixpkgs revision. The lock keeps this checkout reproducible; advance it intentionally when a newer upstream revision is desired.
- Replaced the broad `nup` alias (`nix flake update`, which could update unrelated inputs and depended on the current directory) with a privileged CachyOS-only update targeting `/etc/nixos/nixos`.

### Fixed
- Made the installer roll back the prior NixOS flake files, hardware configuration, VFIO hook directory, and deployed VM XML when a non-zero exit occurs after deployment begins. The XML is now included in the pre-change backup set, and targets that did not previously exist are removed during rollback.
- Updated the VFIO hook to persist the pre-VM active state of `greetd`, `ollama`, and `polkit.service` under `/run/libvirt/vfio-state`; VM release and prepare rollback now start only services that were active before handoff. Added mocked regression coverage for active and inactive states.
- Changed the installer to stop by default before deployment on non-AMD or unidentified CPU/GPU hardware rather than proceed with an AMD-only configuration after a warning.
- Documented the upstream CS2/Source 2 frame-pacing caveat for the globally enabled Vulkan latency layer, including the `fps_max 0` workaround and per-game opt-out.
- Added a dedicated rollback regression test and made it a required CI step; retained the explicit RT-Bore-LTO ThinLTO selection.
- Corrected the Fail2ban comment so it matches the active setting: only loopback is exempt; private LAN ranges remain bannable.
- Added an installer preflight check for `/etc/nixos/hashedPassword` presence, non-empty content, root ownership, and mode `0600`. This is warning-only so the documented manual setup can fix the file before activation.
- Reject running the installer from `/etc/nixos` before system changes, trim monitor-name input before using it in Hyprland defaults, and abort VM XML synchronization unless exactly two real PCI `hostdev` elements have supported source-address blocks. Added regression coverage for malformed/incomplete/extra PCI pairs and whitespace-only monitor input.
- Corrected the Rofi theme comment without changing the working `arthur` binding; clarified that `wuwa-gemma` is a custom Ollama alias based on Aya Expanse 8B, not a Gemma-family model.
- Restricted installer XML address synchronization to PCI `hostdev` nodes, fixed warnings for incomplete versus extra PCI entries, and added a regression test that ensures USB address sources are never rewritten as PCI addresses.
- Aligned the README with the default VM XML and documented the two active fixed USB passthrough IDs. The system-wide Reflex configuration is now enabled again; per-game opt-out is documented for incompatible Vulkan applications.
- Clarified that installer host-device counts and synchronization refer to PCI `hostdev` entries, not all device types; extended the VM XML regression test to guard the documented USB IDs as well as the PCI pair.
- Clarified single-GPU recovery guidance and changed the hook to terminate only `seat0`, preserving headless SSH sessions while retaining the fail-closed GPU-use check. Removed a duplicate `android-file-transfer` package entry and corrected a stale Home Manager package-list comment.
- Removed the unused Waypaper package and `SUPER+W` binding, corrected the installer's missing-PCI-device diagnostic so it does not invoke `lspci` a second time, and translated the color notification title to English.
- Clarified that IOMMU kernel parameters are not enabled by default, corrected the VM input limitation comment, and added a regression check that VM XML GPU/audio PCI addresses match the QEMU hook defaults.
- Standardized root-required commands in the fresh-install guides and preserved the generated NixOS config as a backup before installing the repository tree.
- Fixed the Home Manager startup command so it starts `mpvpaper-watchdog` only when the optional `monitorOutput` is configured; documented the disabled-by-default kernel parameters and correct per-activation swap encryption behavior.
- Removed stale advice to refresh the CachyOS lock for every install and corrected the English changelog's claim about historical version coverage.
- Historical change: the CachyOS input was switched to upstream `release` at that point to align with its cached nixpkgs revision. The current `nixos/flake.nix` follows `master`; `overlays.pinned` still selects the kernel flake’s pinned nixpkgs revision. The upstream Attic cache and public key were also added to the flake and system Nix settings.
- Corrected the Windows VM's Q35 machine alias and made the Windows installation ISO boot ahead of the VirtIO driver ISO. Added a regression test for these XML invariants and wired it into CI.
- Hardened the Ollama fallback translator: HTTP errors, malformed responses, and empty translations now fail without being cached as successful translations.
- Translated English-named project documentation, installer comments/messages, and VFIO hook diagnostics/recovery messages into English. Kept `KURULUM.md` and `DEGISIKLIK_GECMISI.md` in Turkish, while translating comments embedded in installation command examples. Turkish OCR translation notifications remain intentional application UI.
- Replaced stale archive-document wording with English historical summaries so that `docs/` is consistently English and old audit findings are not mistaken for current defects.
- Corrected migration instructions for the required `hashedPassword` file and the VM XML fallback source; updated the related regression test, and guarded against the old undeclared IOMMU path variable recurring. Retracted the false OVMF template mismatch claim, marked old commit hashes as historical, and removed stale guidance to refresh the pinned CachyOS lock for routine installs. The input ZIP did not encode the executable bit for `install.sh`; this follow-up fix bundle restores Unix mode `100755`.
- Corrected the installer and documentation to distinguish the VFIO hook source under `/etc/nixos/nixos/hooks` from the active NixOS-generated libvirt hook, which is refreshed only by a successful rebuild/activation. Clarified that the installer writes but does not automatically define the VM XML, and that timestamped installer backups are not pruned automatically. Translated the remaining Turkish installer risk/compatibility prompts into English and updated their regression assertions; corrected the README's Nix formatting command to format each `.nix` file explicitly.
- Made the password-hash checklist preserve existing valid hashes, aligned the Turkish install guide's root-password command with the post-install stage, and translated the last Turkish comment in active Nix code. The repair bundle encodes `install.sh` as executable in the ZIP itself.
- Hardened the VM XML regression test to require exactly two distinct PCI hostdev addresses matching the QEMU hook, and clarified hook recovery logging when GPU display and GPU audio driver restoration differ.
- Corrected disk-size units in `KURULUM.md` and `README.md` (the `sgdisk` `G` suffix means GiB), added whole-disk, mounted-volume, and minimum-capacity checks before the destructive partition-table wipe, and narrowed the documented GPU target to RX 6700 XT/Navi 22. The fix-only patch ZIP stores `install.sh` with Unix mode `100755`; the originally uploaded full-project ZIP did not preserve that mode.

### Validation
- Bash syntax checks passed for the installer, QEMU hook, and VFIO regression test.
- Python compilation checks passed for the scripts.
- VM XML invariants test passed.
- VFIO driver-state and service-state regression tests passed.
- Installer partial-deployment rollback regression test passed.
- The project owner reported that GitHub Actions CI was green and the previous standard BORE-LTO kernel built successfully on the tested target system: the Windows VM started and the host display/Hyprland session returned after normal VM shutdown. This result predates the RT-Bore-LTO switch and does not validate the newly selected uncached RT/LTO kernel. This is owner-reported hardware validation, not independent reproduction by the reviewer and not a compatibility guarantee for other hardware. The review environment lacked Nix, ShellCheck, and libvirt/QEMU tools, so independent flake evaluation/build, ShellCheck, and semantic VM validation were not performed. The checked-in `flake.lock` pins the CachyOS `master` input at `873c5a2a40575b880a962aaade19afbb572adf92` (reported as Linux 7.2.9); newer upstream revisions still require an intentional input update. The selected RT-Bore-LTO LTO variant is not published in the upstream binary cache and therefore requires a local build.

## Historical releases

The detailed Turkish changelog is preserved in [`DEGISIKLIK_GECMISI.md`](DEGISIKLIK_GECMISI.md). This English index intentionally avoids restating historical claims as if they were re-tested against the current tree; consult the Turkish file for the release entries it actually contains.

# Repair and validation report — 2026-10-16

## Scope

Reviewed the uploaded source archive and modified source files, configuration, VM XML, installer, CI, scripts, and documentation. This is a static maintenance pass, not a claim that the configuration was activated on the target PC.

## Follow-up status — 2026-10-16: RT-Bore-LTO selected

The current `nixos/flake.nix` selects `pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto`. Upstream explicitly says the RT-Bore-LTO LTO variant is not published to its binary cache, so expect a local kernel build; the `pinned` overlay aligns nixpkgs revisions but cannot create a missing cache artifact. The stale CachyOS lock was corrected to `873c5a2a40575b880a962aaade19afbb572adf92`, and its nested nixpkgs input now matches `6aa7ad7f840d5a5bf17020b231d1c8d87a71995b`. Upstream `version.json` at that revision selects RT-Bore 7.2.9. The earlier user-provided linker log named standard BORE-LTO 7.2.9, which is a different package derivation and does not prove or disprove the RT-Bore-LTO build. This audit environment has no Nix CLI, so package evaluation and compilation were not run here.

The previously reported successful target-machine build and VM display recovery were performed with the standard (non-RT) BORE-LTO kernel. They do not validate the newly selected RT-Bore-LTO kernel. After a successful build, boot it and test VM start, normal shutdown, host display/Hyprland recovery, and a second VM start before treating the migration as validated. Upstream package reference: https://github.com/xddxdd/nix-cachyos-kernel/blob/873c5a2a40575b880a962aaade19afbb572adf92/README.md

## Corrections applied for the 2026-10-16 audit

- `KURULUM.md` now states the 810 GiB minimum (about 870 GB decimal) and explicitly documents that the `G` suffix accepted by `sgdisk` represents GiB. The reference partitions total 809 GiB.
- Before `sgdisk -Z` can run, the guide checks that the target exists, is a whole-disk block device, has no mounted descendants, and is at least 810 GiB. These checks reduce common mistakes but do not replace the operator's final model/serial-number verification; `sgdisk -Z` remains destructive.
- `KURULUM.md` and `README.md` now identify RX 6700 XT/Navi 22 as the reference GPU and do not imply universal support for RX 6000/7000 cards.
- The original uploaded full-project ZIP's missing Unix executable bit is distinguished from the new patch-only ZIP, which stores `install.sh` as mode `100755`. This patch archive contains only the corrected paths, not a duplicate full project or `.git` metadata.

## Changes made

### CachyOS kernel build/cache path

- Changed the CachyOS flake input from the default `master` branch to `github:xddxdd/nix-cachyos-kernel/release`. [Upstream documentation](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md) says this branch contains a kernel built by its Hydra CI and published to its binary cache.
- Changed `cachyos-kernel.overlays.default` to `cachyos-kernel.overlays.pinned`, which selects packages from the kernel flake's pinned nixpkgs revision. See the [upstream overlay definition](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix). For variants that upstream actually caches, this can avoid a local ThinLTO build when a matching derivation exists. RT-Bore-LTO's LTO variant is not cached, as noted in the follow-up status above.
- Replaced the previous CachyOS cache entry with the Attic substituter and public key documented by upstream in both the flake `nixConfig` and system Nix settings. [Upstream cache configuration](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix).
- The previous archive's CachyOS lock was stale at release commit `b1332396df6e880d7e3b6b451c6a74132ce8cf66` (Linux 7.2.8). This correction updates `nixos/flake.lock` to `873c5a2a40575b880a962aaade19afbb572adf92` (Linux 7.2.9) and the matching nested nixpkgs revision. The lock remains deliberate and reproducible; update it again only when intentionally moving to a newer upstream kernel. RT-Bore-LTO LTO is not in the upstream binary cache, so local build failures such as linker regressions still need their own investigation.

### Windows VM XML

- Changed the Q35 machine alias from `pc-q35` to `q35`. A versioned alias such as `pc-q35-X.Y` may also be used if that exact version is supported by the installed QEMU/libvirt.
- Reordered CD-ROM boot priorities so the Windows installation ISO is attempted before the VirtIO driver ISO. The disk remains boot priority 1.
- Added `scripts/test-vm-xml.py`, which parses the XML and checks the machine alias, disk/CD-ROM priority, SATA CD-ROM bus, and complete PCI hostdev addresses. CI runs this test.

### Ollama translation fallback

- Changed the API call to fail on HTTP error responses and display transport errors.
- Added validation that the response includes a non-empty string `response` property.
- Removed use of `xargs` as a generic whitespace trimmer, so quotes/backslashes are not reinterpreted. Empty/error responses now fail and are not appended to the translation cache.

### Documentation and language consistency

- Rewrote the English-named `README.md`, `CONTRIBUTING.md`, and `CHANGELOG.md` in English. Preserved the full historical Turkish changelog in the Turkish-named `DEGISIKLIK_GECMISI.md`.
- Kept `KURULUM.md` in Turkish and translated comments embedded in its command examples into English.
- Translated installer prompts, warnings, desktop labels, status messages, notifications, service descriptions, and VFIO hook comments into English; translated the remaining LLM-fallback comment in `nixos/home.nix` as well. The translation result itself remains Turkish by design because the OCR utility translates English game text into Turkish.
- Renamed archived reports with English filenames and replaced obsolete Turkish audit snapshots with English historical summaries. The current audit scope and known limitations are documented here.

## Checks performed in this environment

| Check | Result |
|---|---|
| `bash -n install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh` | Passed |
| `bash scripts/test-installer-invariants.sh` | Passed |
| `python3 -m py_compile` for repository Python scripts | Passed |
| `python3 scripts/test-vm-xml.py` | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | Passed |
| ZIP/tree and JSON/YAML/XML parsing | Passed where relevant tooling was available |
| GitHub Actions CI | The project owner reports that CI is green for the updated repository; this status was not independently re-run from the audit container. |
| Nix evaluation / `nixos-rebuild dry-activate` | Not run by this reviewer: `nix` is unavailable in the audit environment. The project owner separately reports a successful target-system rebuild; whether the exact `dry-activate` command was run was not specified. |
| `shellcheck`, `xmllint`, `virt-xml-validate` | Not run: tools are unavailable in this environment |
| Real VM/GPU lifecycle | Not independently run by this reviewer. The project owner reported a successful VM lifecycle on the prior standard (non-RT) BORE-LTO kernel. That result does not validate the current RT-Bore-LTO selection; boot and VM lifecycle testing remain required after its build. |

The checked-in `flake.lock` now points to the CachyOS `release` revision `873c5a2a40575b880a962aaade19afbb572adf92` (Linux 7.2.9), rather than the stale 7.2.8 snapshot. Nix is unavailable in the review environment, so this reviewer did not run flake evaluation or a kernel build. The project owner reported that the rebuild and standard (non-RT) BORE-LTO kernel build succeeded on the target system and that the VM-start/normal-shutdown path restored the host display and Hyprland. That historical result applies only to the prior kernel; the newly selected RT-Bore-LTO variant remains unbuilt and unvalidated in this audit. This is owner-reported evidence rather than a result independently reproduced in this container; it does not, by itself, establish whether the kernel came from the binary cache or was compiled locally.

## Required checks on the target NixOS host

From `/etc/nixos/nixos/`:

```bash
nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false
sudo nixos-rebuild dry-activate --flake .#nixos -L
```

Watch whether the kernel is substituted from cache or built locally. If the same `tools/bpf/resolve_btfids` `ld.lld: undefined symbol` error recurs, capture the full derivation log with `nix log /nix/store/<kernel-derivation>.drv`; a lock/cache change does not itself fix a linker bug in source. Keep the currently working system generation until the candidate generation succeeds.

The project owner has confirmed a successful VM start, normal shutdown, and host compositor recovery on the target machine; this closes the previously reported VM recovery issue for that setup. After future kernel, firmware, PCI-layout, VM XML, or hook changes, repeat the lifecycle check and inspect GPU/audio driver restoration. XML parsing is not a substitute for libvirt/QEMU validation or a real boot.


## Follow-up fixes in the reviewed archive

- Defined `PATCHED_XML=/var/lib/libvirt/win10.xml` before its first use in `install.sh` and translated the remaining installer prompt/help strings. The originally uploaded full-project ZIP did not encode Unix permission bits for `install.sh`, so extraction produced mode `0644` even though the Git index records `100755`. The fix-only patch ZIP for the 2026-10-16 corrections stores `install.sh` as mode `100755`; this statement is verified against the patch archive, not inferred from the Git index.
- The installer backs up an existing deployed VM XML, then regenerates it from the repository template while preserving the existing UUID and MAC and synchronizing GPU/audio PCI addresses; arbitrary custom XML edits are not merged into the regenerated file. Manual-copy instructions warn that host-specific PCI addresses must be checked.
- Documented a manual migration prerequisite check for `/etc/nixos/hashedPassword` in `README.md`, including non-empty content, root ownership, and mode `0600`, before rebuild commands. The installer now performs the same presence/metadata check during preflight and warns without aborting, because the manual checklist may still need to create or repair the file. Its example creates a hash only when the file is missing or empty, preserving an existing valid hash. Added a regression assertion that rejects the former undeclared `iommu_dir` spelling; the checked-in installer already uses the declared `gpu_iommu_dir`.
- Retracted the false OVMF template-architecture finding, corrected historical HEAD wording, and removed stale advice to refresh the CachyOS lock during routine installation.
- Set all configured locale categories and the supported generated locale to `en_US.UTF-8`. The Turkish Q keyboard mapping remains intentionally configured as a physical keyboard-layout choice, not as the system language.
- Translated remaining Waybar/Hyprlock labels, notifications, service descriptions, runtime errors, hook comments, and the commented USB-input XML notes into English. Translation output from the OCR/game translation feature remains Turkish intentionally.
- Added `scripts/test-installer-invariants.sh` and connected it to CI to guard the XML destination, preservation of deployed XML, English locale, and known user-visible strings.
- Added a Windows 10 lifecycle warning to the README; standard Home/Pro support ended on October 14, 2025.
- Corrected the installer's preflight summary to disclose its real system-changing behavior, including replacement of the deployed hook directory, writing the deployed VM XML, and pruning older timestamped installer backups. Expanded the README migration warning to document these operations.
- Replaced the ambiguous `nixfmt ./nixos` README command with a `find`/`xargs` pipeline that invokes `nixfmt` separately on each `.nix` file.
- Hardened `scripts/test-vm-xml.py`: the checked-in template must contain exactly two PCI `hostdev` elements, their source addresses must be unique, and they must match the two distinct hook defaults.
- Clarified the VFIO release log so it distinguishes restoration of the GPU display function from restoration of the HDMI/DP audio function; a restored display GPU no longer implies that both functions recovered.
- Made the installer checklist non-destructive for `hashedPassword`, translated the final remaining Turkish source comment, and moved the `nixos-enter ... passwd root` instruction to after successful `nixos-install` in `KURULUM.md`.

## Follow-up validation of this fix bundle

- The fix-only patch ZIP produced for the 2026-10-16 corrections stores `install.sh` with Unix mode `100755`. The original full-project ZIP is intentionally not included or repackaged in this patch-only delivery; apply these files over the project tree and create a fresh full-project archive from the corrected tree when needed. ZIP mode was read back from the produced patch archive, not inferred from the Git index.
- The pre-existing validation suite passed again for the 2026-10-16 correction set: `bash -n` for the installer, QEMU hook, and regression tests; `scripts/test-installer-invariants.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-vm-xml.py`; Python compilation for repository scripts; JSON parsing for `flake.lock`; and XML parsing for `win10.xml`. The newly added disk preflight code block in `KURULUM.md` was also extracted and Bash-syntax-checked. These checks do not simulate a real disk operation or VM lifecycle. Negative tests in the existing suite also confirm that duplicate PCI addresses and a third PCI `hostdev` are rejected.
- `shellcheck`, Nix evaluation/build, and libvirt validation were not run by this reviewer because the required tools are unavailable in the preparation environment. Real hardware tests were also not run independently by this reviewer. The project owner confirms the VM problem is resolved on the target system: rebuild and BORE-LTO kernel build succeeded, the VM started and shut down normally, and the display/Hyprland session recovered. The report records this as owner-verified real-system validation, not independent reproduction or a general guarantee for other hardware.

- The privileged XML updater uses the already-resolved Python interpreter. XML parsing errors, an incomplete/extra PCI `hostdev` pair, or a PCI node whose source-address structure cannot be synchronized now abort before a VM XML backup/write. Added a preflight guard against running the checkout from `/etc/nixos` (which would overlap source and destination), trimmed monitor-name input before generating Hyprland defaults, and expanded the installer regression tests. Source ZIPs should be built from Git so `install.sh` remains mode `100755`; patch ZIP delivery independently stores that mode in the archive metadata.


## Latest requested configuration changes — 2026-10-16

- The RT-Bore-LTO package follows `github:xddxdd/nix-cachyos-kernel/release`; the package version is not hard-coded in `flake.nix`. This correction updates `flake.lock` to the known upstream 7.2.9 revision. Future upstream versions still require an intentional `nix flake update cachyos-kernel --accept-flake-config` and review of the lock diff. The `nup` Fish alias now runs that targeted update against `/etc/nixos/nixos`, rather than updating all flake inputs from the current directory.
- `LOW_LATENCY_LAYER=1` and `LOW_LATENCY_LAYER_REFLEX=1` are set through `environment.sessionVariables` so PAM-launched desktop sessions receive the system-wide Reflex setting. Affected applications may opt out with `DISABLE_LOW_LATENCY_LAYER=1`.
- OpenSSH password authentication is enabled for `localhost` only, root login is disabled, TCP/22 is permitted by the firewall, and Fail2ban no longer exempts RFC1918 ranges. The contradictory Fail2ban comment was removed. The installer now checks the SSH hash file's presence and `root:root:0600` metadata during preflight and warns if setup is incomplete. The QEMU hook terminates only `seat0` rather than all sessions for the desktop user, preserving a remote SSH session. The existing GPU-node check still aborts and rolls back if a process retains the device.
- This environment did not run Nix evaluation or build the RT-Bore-LTO kernel. Test the lock update, full rebuild, SSH persistence during VM startup, and complete VM stop/host-GPU recovery sequence on the target system before relying on these changes.

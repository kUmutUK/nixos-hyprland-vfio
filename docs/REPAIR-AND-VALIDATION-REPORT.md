# Repair and validation report — 2026-10-15

## Scope

Reviewed the uploaded source archive and modified source files, configuration, VM XML, installer, CI, scripts, and documentation. This is a static maintenance pass, not a claim that the configuration was activated on the target PC.

## Changes made

### CachyOS kernel build/cache path

- Changed the CachyOS flake input from the default `master` branch to `github:xddxdd/nix-cachyos-kernel/release`. [Upstream documentation](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md) says this branch contains a kernel built by its Hydra CI and published to its binary cache.
- Changed `cachyos-kernel.overlays.default` to `cachyos-kernel.overlays.pinned`, which selects packages from the kernel flake's pinned nixpkgs revision. See the [upstream overlay definition](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix). This can avoid a local ThinLTO build when a matching cached derivation exists.
- Replaced the previous CachyOS cache entry with the Attic substituter and public key documented by upstream in both the flake `nixConfig` and system Nix settings. [Upstream cache configuration](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix).
- In this archive, `flake.lock` already pins the CachyOS input to release commit `873c5a2a40575b880a962aaade19afbb572adf92` with the corresponding NAR hash. No lock refresh is required just to apply the fixes in this report. A cache miss can still trigger a local build; the configuration changes cannot repair an upstream source-level linker regression if the cache is unavailable.

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
- Translated installer prompts, warnings, code comments, desktop labels, status messages, notifications, service descriptions, and VFIO hook comments into English. The translation result itself remains Turkish by design because the OCR utility translates English game text into Turkish.
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
| Nix evaluation / `nixos-rebuild dry-activate` | Not run: `nix` is unavailable in this environment |
| `shellcheck`, `xmllint`, `virt-xml-validate` | Not run: tools are unavailable in this environment |
| Real RX 6700 XT VM start/shutdown/driver restoration | Not run: requires the target host and hardware |

The checked-in `flake.lock` in this archive already points to the CachyOS `release` commit listed above. Nix is unavailable in the preparation environment, so neither flake evaluation nor a kernel build was run here. The lock state is therefore verified from the file contents, but successful cache substitution and kernel compilation still need to be checked on the target host.

## Required checks on the target NixOS host

From `/etc/nixos/nixos/`:

```bash
sudo nix flake check --no-build --show-trace --no-update-lock-file
sudo nixos-rebuild dry-activate --flake .#nixos -L
```

Watch whether the kernel is substituted from cache or built locally. If the same `tools/bpf/resolve_btfids` `ld.lld: undefined symbol` error recurs, capture the full derivation log with `nix log /nix/store/<kernel-derivation>.drv`; a lock/cache change does not itself fix a linker bug in source. Keep the currently working system generation until the candidate generation succeeds.

Before relying on single-GPU passthrough, test VM startup from a separate TTY/SSH session, a clean guest shutdown, GPU and audio driver restoration, host compositor recovery, and a second VM start. XML parsing is not a substitute for libvirt/QEMU validation or a real boot.


## Follow-up fixes in the reviewed archive

- Defined `PATCHED_XML=/var/lib/libvirt/win10.xml` before its first use in `install.sh` and translated the remaining installer prompt/help strings. The input ZIP did not encode Unix permission bits for `install.sh`, so extraction produced mode `0644` even though the Git index records `100755`. This follow-up fix bundle explicitly stores `install.sh` as mode `100755`.
- Kept an already-deployed VM XML intact and corrected the README fallback to copy `vm-xml/win10.xml` from the repository root only when no deployed XML exists. The manual-copy path warns that host-specific PCI addresses must be checked.
- Added a migration prerequisite check for `/etc/nixos/hashedPassword`, including root ownership and mode `0600`, before the rebuild commands. Added a regression assertion that rejects the former undeclared `iommu_dir` spelling; the checked-in installer already uses the declared `gpu_iommu_dir`.
- Retracted the false OVMF template-architecture finding, corrected historical HEAD wording, and removed stale advice to refresh the CachyOS lock during routine installation.
- Set all configured locale categories and the supported generated locale to `en_US.UTF-8`. The Turkish Q keyboard mapping remains intentionally configured as a physical keyboard-layout choice, not as the system language.
- Translated remaining Waybar/Hyprlock labels, notifications, service descriptions, runtime errors, hook comments, and the commented USB-input XML notes into English. Translation output from the OCR/game translation feature remains Turkish intentionally.
- Added `scripts/test-installer-invariants.sh` and connected it to CI to guard the XML destination, preservation of deployed XML, English locale, and known user-visible strings.
- Added a Windows 10 lifecycle warning to the README; standard Home/Pro support ended on October 14, 2025.
- Corrected the installer's preflight summary to disclose its real system-changing behavior, including replacement of the deployed hook directory, writing the deployed VM XML, and pruning older timestamped installer backups. Expanded the README migration warning to document these operations.
- Replaced the ambiguous `nixfmt ./nixos` README command with a `find`/`xargs` pipeline that invokes `nixfmt` separately on each `.nix` file.
- Hardened `scripts/test-vm-xml.py`: the checked-in template must contain exactly two PCI `hostdev` elements, their source addresses must be unique, and they must match the two distinct hook defaults.
- Clarified the VFIO release log so it distinguishes restoration of the GPU display function from restoration of the HDMI/DP audio function; a restored display GPU no longer implies that both functions recovered.

## Follow-up validation of this fix bundle

- `install.sh` is packaged with Unix mode `100755`, consistent with the Git index and the README's direct `./install.sh` invocation.
- Passed after these edits: `bash -n` for the installer, QEMU hook, and regression tests; `scripts/test-installer-invariants.sh`; `scripts/test-vfio-hook-driver-state.sh`; `scripts/test-vm-xml.py`; Python compilation for the repository scripts; and XML parsing. Negative tests also confirmed that duplicate PCI addresses and a third PCI `hostdev` are rejected.
- `shellcheck`, Nix evaluation/build, libvirt validation, and real hardware lifecycle checks remain unrun because the required tools or target hardware are unavailable in this preparation environment.

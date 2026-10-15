# Repair and validation report — 2026-10-15

## Scope

Reviewed the uploaded source archive and modified source files, configuration, VM XML, installer, CI, scripts, and documentation. This is a static maintenance pass, not a claim that the configuration was activated on the target PC.

## Changes made

### CachyOS kernel build/cache path

- Changed the CachyOS flake input from the default `master` branch to `github:xddxdd/nix-cachyos-kernel/release`. [Upstream documentation](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/README.md) says this branch contains a kernel built by its Hydra CI and published to its binary cache.
- Changed `cachyos-kernel.overlays.default` to `cachyos-kernel.overlays.pinned`, which selects packages from the kernel flake's pinned nixpkgs revision. See the [upstream overlay definition](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix). This can avoid a local ThinLTO build when a matching cached derivation exists.
- Replaced the previous CachyOS cache entry with the Attic substituter and public key documented by upstream in both the flake `nixConfig` and system Nix settings. [Upstream cache configuration](https://github.com/xddxdd/nix-cachyos-kernel/blob/release/flake.nix).
- Updated the input's `original.ref` in `flake.lock`, but the locked revision/hash has not been regenerated in this environment. **Before building, run** `sudo nix flake lock --update-input cachyos-kernel` from `nixos/`, review the resulting lock diff, and commit it. A cache miss can still trigger a local build; the configuration changes cannot repair an upstream source-level linker regression if the cache is unavailable.

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
- Translated installer prompts, warnings, and code comments into English; translated VFIO hook log/recovery messages and comments into English. Turkish notifications inside the OCR translation utility remain Turkish intentionally because they are end-user UI text for an English-to-Turkish workflow.
- Renamed archived reports with English filenames and replaced obsolete Turkish audit snapshots with English historical summaries. The current audit scope and known limitations are documented here.

## Checks performed in this environment

| Check | Result |
|---|---|
| `bash -n install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh` | Passed |
| `python3 -m py_compile` for repository Python scripts | Passed |
| `python3 scripts/test-vm-xml.py` | Passed |
| `bash scripts/test-vfio-hook-driver-state.sh` | Passed |
| ZIP/tree and JSON/YAML/XML parsing | Passed where relevant tooling was available |
| Nix evaluation / `nixos-rebuild dry-activate` | Not run: `nix` is unavailable in this environment |
| `shellcheck`, `xmllint`, `virt-xml-validate` | Not run: tools are unavailable in this environment |
| Real RX 6700 XT VM start/shutdown/driver restoration | Not run: requires the target host and hardware |

The environment used to prepare this archive does not have Nix or network access from the container, so it was not possible to regenerate and verify the new CachyOS release input lock node here. The source requests the `release` branch, but `flake.lock` still points to the previously locked kernel commit until the explicit lock refresh below is run. Treat that refresh as a required part of applying this repair; the ZIP is not claiming that the kernel rebuild has already been proven successful.

## Required checks on the target NixOS host

From `/etc/nixos/nixos/`:

```bash
sudo nix flake lock --update-input cachyos-kernel
sudo nix flake check --no-build --show-trace --no-update-lock-file
sudo nixos-rebuild dry-activate --flake .#nixos -L
```

Watch whether the kernel is substituted from cache or built locally. If the same `tools/bpf/resolve_btfids` `ld.lld: undefined symbol` error recurs after cache refresh, capture the full derivation log with `nix log /nix/store/<kernel-derivation>.drv`; a lock/cache change does not itself fix a linker bug in source. Keep the currently working system generation until the candidate generation succeeds.

Before relying on single-GPU passthrough, test VM startup from a separate TTY/SSH session, a clean guest shutdown, GPU and audio driver restoration, host compositor recovery, and a second VM start. XML parsing is not a substitute for libvirt/QEMU validation or a real boot.

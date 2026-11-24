# Contributing

Thank you for helping improve this project. Because this is a hardware-specific NixOS configuration, changes should be reproducible, clearly scoped, and explicit about what was and was not tested.

## Workflow

1. Fork the repository.
2. Create a focused feature branch:
   ```bash
   git checkout -b feature/my-change
   ```
3. Make the smallest change that addresses the issue.
4. Run the relevant checks below and include their results in the pull request.
5. Open a pull request with a clear explanation and reproduction steps.

## Validation

Run these commands from the repository root. Go is required for the pinned Actionlint invocation.

**Current flake input identities (25 November 2026):** `nixos/flake.lock` pins the CachyOS kernel flake source to `306480b9096055a06503167f975c027e244dd839` (the upstream `xddxdd/nix-cachyos-kernel` `release` ref). Its **nested CachyOS Nixpkgs package set** is the separate `nixos-unstable-small` revision `616ae05a769a23c143b19746b6a3b06366a9a28f`. The root NixOS system/userland uses its own `nixos-unstable` Nixpkgs revision `2786a2a72088ecf32aea5b3ec52099e6a7cff78f`. Resolve each node through its owning flake input in `flake.lock`; do not treat the nested package set as the root system/userland Nixpkgs. For historical comparison, Build #19 used CachyOS source `9df32f70be3550911f178b3ba9ad784996a4e80c`, nested Nixpkgs `4d6a01a11146f4691c0991682885ad9e4686e3ee`, and root Nixpkgs `f4a03c008967841f2a0b3cb7c436fc6fc31671f6`. That is a separate historical lock tuple, not the current input set.

**Historical Build #21 distance:** Build #21 source `672d255d4a921c097dd69eae817e8dc9699380d6` was 20 commits and 39 changed paths behind the v1.6.0 release tag, and 26 commits and 39 changed paths behind the audited pre-update `main` baseline `9e399dcbe96a82a91d03e95fe2251f4e437eadb7`. These are historical source-range measurements; Build #22 superseded Build #21 as the latest retained successful full-system build.


**Installer validation boundary:** CI and the commands below cover Bash syntax, ShellCheck, installer invariants, and mocked rollback behavior. Release #52 accepted `TARGET_HOST_VALIDATED=true` for exact v1.6.0 tag source `3c518e45d979db3234f7628ccbf3979a0057dcf2`; this is a maintainer attestation and the supporting transcript is not committed. The audited main baseline is six commits and 15 changed paths after v1.6.0; `install.sh` changed by 36 insertions and one deletion. The x86-64-v3 CPU/OS feature preflight in the audited main installer is not covered by the tag attestation. A reviewer cannot independently reproduce the live migration/rollback result from retained evidence. Keep the helper experimental and record static tests separately from physical validation.

**Full-system release gate:** the latest retained GitHub full-system result is Build #22 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44623962158) on `d845ccfb5dec3daf705b59bc29f2e5f14e4ee767`, using the previous 19 November lock tuple. It does not build the merged 24 November lock or this feature branch. The feature branch's exact-source Normal CI #1765 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45483814217) passed, but Normal CI is not a full NixOS system build. Run the manual Full NixOS System Build against the exact feature-branch commit before release.

**Historical CI baseline:** Normal CI #1669 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44603757865) passed on the audited pre-update `main` commit `9e399dcbe96a82a91d03e95fe2251f4e437eadb7`; the exact v1.6.0 tag source `3c518e45d979db3234f7628ccbf3979a0057dcf2` separately passed Normal CI #1663 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44593727498). The audited baseline was six commits and 15 changed paths after the v1.6.0 tag; `install.sh` changed by 36 insertions and one deletion. Build #21's 20-commit/39-path and 26-commit/39-path distances are historical; Build #22 is the latest retained full-system build.

```bash
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/*.yml
nix develop ./nixos --command bash -euo pipefail -c '
  for f in install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh scripts/test-installer-lock.sh nixos/hosts/nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh scripts/backup-vm.sh scripts/test-backup-vm.sh scripts/vfio-health.sh scripts/test-vfio-health.sh scripts/waybar-amdgpu.sh scripts/test-waybar-amdgpu.sh scripts/host-profile.sh scripts/test-host-profile.sh scripts/automated-vm-backup.sh scripts/test-automated-vm-backup.sh scripts/benchmark-capture.sh nixos/kernel-manager.sh; do
    bash -n "$f"
  done
  find ./nixos -type f -name "*.nix" -print0 | xargs -0 -r nixfmt --check
  shellcheck -S warning install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh nixos/hosts/nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-lock.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh scripts/backup-vm.sh scripts/test-backup-vm.sh scripts/vfio-health.sh scripts/test-vfio-health.sh scripts/waybar-amdgpu.sh scripts/test-waybar-amdgpu.sh scripts/host-profile.sh scripts/test-host-profile.sh scripts/automated-vm-backup.sh scripts/test-automated-vm-backup.sh scripts/benchmark-capture.sh nixos/kernel-manager.sh
  lua_file="$(mktemp)"
  trap "rm -f $lua_file" EXIT
  (cd nixos && nix eval --raw --no-update-lock-file ".#nixosConfigurations.nixos.config.home-manager.users.localhost.xdg.configFile.\"hypr/hyprland.lua\".text" > "$lua_file")
  (cd nixos && nix develop . --no-update-lock-file --command luac -p "$lua_file")
  python3 -c "import xml.etree.ElementTree as ET; ET.parse(\"vm-xml/win10.xml\")"
  python3 scripts/test-lsfg-vk-v2.py
  python3 scripts/test-mako-renderer.py
  python3 scripts/test-documentation-integrity.py
  python3 scripts/test-release-workflow-python.py
  python3 scripts/test-optiscaler-manager.py
  python3 scripts/test-home-snapper-layout.py
  python3 scripts/test-vm-iso-paths.py
  bash scripts/test-manual-vm-bootstrap.sh
  python3 scripts/test-vm-xml.py
  python3 scripts/test-vm-xml-structure.py
  python3 scripts/test-vm-xml-paths.py
  python3 scripts/test-vm-xml-sync.py
  python3 scripts/test-vm-diagnostic.py
  python3 scripts/test-extract-embedded-scripts.py
  bash scripts/test-installer-lock.sh
  bash scripts/test-source-revision.sh
  bash scripts/test-installer-invariants.sh
  bash scripts/test-installer-rollback.sh
  bash scripts/test-vfio-hook-driver-state.sh
  bash scripts/test-waybar-amdgpu.sh
  bash scripts/test-host-profile.sh
  bash scripts/test-automated-vm-backup.sh
  python3 scripts/test-benchmark-report.py
  tmpdir="$(mktemp -d)"
  trap "rm -rf -- \"$tmpdir\"" EXIT
  python3 scripts/extract-embedded-scripts.py "$tmpdir" > "$tmpdir/paths.nul"
  mapfile -d "" -t embedded_scripts < "$tmpdir/paths.nul"
  if [ "${#embedded_scripts[@]}" -ne 7 ]; then
    printf "Expected 7 embedded Bash scripts, found %s\\n" "${#embedded_scripts[@]}" >&2
    exit 1
  fi
  shellcheck -S warning "${embedded_scripts[@]}"
  (cd nixos && nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false)
  (cd nixos && nix build --no-link --no-update-lock-file .#lsfg-vk-v2)
  (cd nixos && nix build --no-link --no-update-lock-file .#mako-renderer)
  statix check .
  deadnix .
'
```

The `scripts/test-release-workflow-python.py` helper extracts and syntax-compiles every embedded Python heredoc in `.github/workflows/release.yml`; this covers workflow code that Actionlint does not parse. The `scripts/pci-address.sh` helper is included in ShellCheck because the installer sources it. The local checks mirror CI's pinned Actionlint command, ShellCheck of the source VFIO hook (`nixos/hosts/nixos/hooks/qemu`), and `luac -p` validation of the generated Hyprland Lua configuration. The normal CI workflow does not build the Nix-generated VFIO wrapper solely to lint it; the source hook and VFIO driver-state regression remain covered. `statix check .` and `deadnix .` are required CI gates; `statix.toml` disables only the style-only repeated-key lint, not actionable static-analysis findings.

## Target-host GameMode GPU index

GameMode's `gpu_device` is the DRM card number (`cardN`), not a PCI BDF. The current configuration deliberately retains `gpu_device = 1`; do not change it based only on the GPU's PCI address. Before changing this host-specific value, verify the actual DRM mapping on the target machine:

```bash
for card in /sys/class/drm/card[0-9]*; do
  test -e "$card/device/vendor" || continue
  printf '%s vendor=%s device=%s path=%s\\n' \
    "$card" \
    "$(cat "$card/device/vendor")" \
    "$(cat "$card/device/device")" \
    "$(readlink -f "$card/device")"
done
```

Confirm which `cardN` resolves to the RX 6700 XT before altering `gpu_device`. The PCI address `0000:0b:00.0` alone does not establish the DRM card number.

Source provenance is part of the migration contract: clean installation, manual migration, and `install.sh` record the actual Git commit in `/etc/nixos/.source-revision`. VM preparation refuses a missing/malformed marker, a different commit, or a dirty checkout. Canonical source ZIPs embed their commit using Git's `export-subst`; arbitrary ZIP exports without that identity are not accepted by the migration helper.

For changes to NixOS options or kernel inputs, also evaluate the relevant output and, where feasible, run a real `nixos-rebuild dry-activate`.

The `scripts/test-vm-xml-sync.py` suite also mocks libvirt to verify that a registered inactive `win10` definition from `virsh dumpxml --inactive` takes precedence over stale/missing `/var/lib/libvirt/win10.xml`, that live and on-disk definitions are backed up, and that failed `virsh` queries abort before modifying files. Do not claim that the full kernel or system builds unless the build was actually completed. The `--no-build` CI step only evaluates the flake; a separate targeted build verifies the selected LSFG-VK package. The Nix formatting check uses `nixfmt --check` and does not rewrite source files.

The 2026-10-16 hardware result documented in README.md was obtained with standard (non-RT) BORE-LTO and is historical. **Owner-reported local full-system build and VM check (16 November 2026) — latest target-machine update (owner-reported, 16 November 2026):** the owner reported a successful from-scratch full NixOS system build and ordinary VM start/shutdown. No exact source SHA, build command/derivation, or booted generation/kernel identity was supplied; this is not a GitHub Actions run and does not prove that the exact Build #21 kernel was activated or booted. **Current repository/release status (25 November 2026):** the latest published release is v1.6.2 (GitHub Release ID `457366336`), whose annotated tag points to `622183e9bbaeebfa49c33b92e94fe42d4ceb91e`; its 582,590-byte source ZIP has GitHub-reported SHA-256 `52fcdbfda4212cb9ca4ac9e2739097e16844353643ba80fccf751253828d6bdd`. Current `main` is `3b1c6a142ce0a9ae83cfb44d3f514be57f0799d9`; PR #33 and #34 are merged. Normal CI [run 45504325645](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45504325645) passed on that exact SHA. Full NixOS System Build [run 45507035118](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/45507035118) failed during Home Manager evaluation because `home.nix` pointed at missing `nixos/scripts/waybar-amdgpu.sh`. The fix branch aligns Home Manager with the dual-layout resolver used by `configuration.nix` and adds a regression check; its own CI and a fresh full-system build are still required. Build #22 remains the last successful full-system build, but it covers an older commit and lock tuple, not the Serpantinum-integrated main source. The 24 November UWSM rebuild confirmation remains an owner report, not a retained exact-source CI transcript.

**Target-machine validation chronology:** latest clean-install/VM-lifecycle validation (the latest target-machine update dated 2026-11-09, owner-reported clean-install/VM result): NixOS was installed from scratch and the Windows VM completed normal start/shutdown with GPU handback and Hyprland recovery. The "Latest target-machine update" label above (16 November 2026) refers to the separate local full-system build and ordinary VM check, not to this clean-install validation. The historical target-machine update dated 2026-11-03 (3 November 2026) records an earlier local RT-Bore-LTO ThinLTO kernel build and Windows VM lifecycle using CachyOS revision `755712deee259ef7efbfe9154038a270c3d75a87`; it is not the latest host validation.

Historical clean-install and VM result (owner-reported, 9 November 2026): NixOS was installed from scratch without issues on the reference hardware; the Windows 10 VFIO VM started and shut down normally, GPU control returned to the host, and Hyprland resumed. Saved-state/managed-save restore remains unverified.

For VM XML changes, keep the project-specific invariant test up to date and validate the definition with the target host's libvirt/QEMU. A well-formed XML document can still reference an unsupported machine type or unavailable host resources. `vm-xml/win10.xml` is intentionally outside the release ancestor-build allowlist; when it changes since the previous stable tag, release requires the separate `vm_xml_validated=true` manual Release attestation for libvirt/QEMU semantic validation and real Windows plus installed-NixOS `vdb` guest boots. The general `target_host_validated` checkbox does not replace this VM-specific evidence.

For VFIO hook changes, run the mock driver-state regression test and document which branches it covers. It is not a substitute for testing the real GPU lifecycle on hardware. Single-GPU passthrough can terminate the host graphical session; arrange a recovery TTY or SSH path before running it.

## Style

- Use two-space indentation in Nix files and format them with `nixfmt`.
- Use `nixfmt --check` for validation; formatting edits should be reviewed separately.
- Keep shell scripts compatible with the Bash runtime they declare and check them with ShellCheck.
- Prefer declarative NixOS configuration over manual runtime changes.
- Keep comments and documentation accurate; remove stale explanations rather than appending contradictory notes.
- Never commit host-specific secrets, password hashes, personal SSH keys, or test data.

## Pull requests

Include the motivation, a summary of changed files, test output, known limitations, and screenshots only when a UI change needs them. If a change is host-specific, state the required hardware and firmware assumptions.

## Bug reports

Include the NixOS release, `uname -r`, CPU/GPU model, relevant logs, the exact command that failed, and whether the failure occurred during evaluation, derivation building, activation, or runtime. Redact secrets and personal identifiers.

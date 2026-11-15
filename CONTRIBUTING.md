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

**Installer validation boundary:** CI and the commands below cover Bash syntax, ShellCheck, installer invariants, and mocked rollback behavior. No end-to-end run of `install.sh` against a live NixOS/libvirt target host has been completed. A green CI run is not evidence that the helper completed a live deployment or recovered a real target system. Record these as separate validation categories in review notes.

```bash
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/*.yml
nix develop ./nixos --command bash -euo pipefail -c '
  for f in install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh scripts/test-installer-lock.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh; do
    bash -n "$f"
  done
  find ./nixos -type f -name "*.nix" -print0 | xargs -0 -r nixfmt --check
  shellcheck -S warning install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-lock.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh
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

The `scripts/test-release-workflow-python.py` helper extracts and syntax-compiles every embedded Python heredoc in `.github/workflows/release.yml`; this covers workflow code that Actionlint does not parse. The `scripts/pci-address.sh` helper is included in ShellCheck because the installer sources it. The local checks mirror CI's pinned Actionlint command, ShellCheck of the source VFIO hook (`nixos/hooks/qemu`), and `luac -p` validation of the generated Hyprland Lua configuration. The normal CI workflow does not build the Nix-generated VFIO wrapper solely to lint it; the source hook and VFIO driver-state regression remain covered. `statix check .` and `deadnix .` are required CI gates; `statix.toml` disables only the style-only repeated-key lint, not actionable static-analysis findings.

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

The 2026-10-16 hardware result documented in README.md was obtained with standard (non-RT) BORE-LTO and is historical. The latest target-machine update dated 2026-11-09 records the owner-reported clean installation; NixOS was installed from scratch without issues, and the ordinary Windows 10 VFIO VM lifecycle succeeded with GPU handback and Hyprland recovery. This is an owner-reported result and does not establish that `install.sh` was used. The historical target-machine update dated 3 November 2026 records a successful NixOS rebuild, local RT-Bore-LTO ThinLTO kernel compilation, and normal Windows VM start/shutdown with GPU handback and Hyprland recovery (CachyOS revision `755712deee259ef7efbfe9154038a270c3d75a87`). GitHub Full NixOS System Build #20 [run](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43653123079) completed successfully on exact source commit `46d2b809e4fe9530dde58c85450b3544cf5d1ed0`; it built the full system and selected RT-Bore-LTO kernel with current CachyOS `c9620070e884d55c5b5566e3fd46611ee24c4d3b`, nested CachyOS Nixpkgs package set `82566dfe91ca5e12bc10b36272280628142f651d`, and root Nixpkgs `d4f25a3e562008648d45bcf2d70bcc7422cad84e`. The preceding Build #19 used older CachyOS `9df32f70be3550911f178b3ba9ad784996a4e80c` and root Nixpkgs `4d6a01a11146f4691c0991682885ad9e4686e3ee`. Build #20 validates compilation, not activation or boot on physical hardware. The exact kernel SHA used during the 9 November target-host test remains unknown. A live `install.sh` migration/rollback, physical boot and post-boot graphics/VM recovery, real saved-state/managed-save restore, and complete dual-guest Windows/NixOS boot validation remain open.

For VM XML changes, keep the project-specific invariant test up to date and validate the definition with the target host's libvirt/QEMU. A well-formed XML document can still reference an unsupported machine type or unavailable host resources.

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

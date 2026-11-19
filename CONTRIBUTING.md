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

**Installer validation boundary:** CI and the commands below cover Bash syntax, ShellCheck, installer invariants, and mocked rollback behavior. Release #50 accepted `TARGET_HOST_VALIDATED=true` for exact v1.6.0 commit `93b8929f5aff5eec17a40afc3f3e91c3443a5c11`, but that maintainer attestation has no committed host transcript and does not cover later commits on current `main`; the current `install.sh` changed after the tag. Therefore the current installer revision has no retained target-host validation evidence. A green CI run is not evidence that this later helper revision completed a live deployment or recovered a real target system. Record these as separate validation categories in review notes.

```bash
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/*.yml
nix develop ./nixos --command bash -euo pipefail -c '
  for f in install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh scripts/test-installer-lock.sh nixos/hosts/nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh; do
    bash -n "$f"
  done
  find ./nixos -type f -name "*.nix" -print0 | xargs -0 -r nixfmt --check
  shellcheck -S warning install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh nixos/hosts/nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-lock.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh
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

The 2026-10-16 hardware result documented in README.md was obtained with standard (non-RT) BORE-LTO and is historical. **Latest target-machine update (owner-reported, 16 November 2026):** the **Owner-reported local full-system build and VM check (16 November 2026)** records a successful from-scratch full NixOS system build and VM start/shutdown. No exact source SHA, build command/derivation, or booted generation/kernel identity was supplied; this is not a GitHub Actions run and does not prove that the exact Build #20 kernel was activated or booted. The 16 November owner note explicitly said that `install.sh` had not been tried. Release #50 later accepted `TARGET_HOST_VALIDATED=true` for exact commit `93b8929f5aff5eec17a40afc3f3e91c3443a5c11` — the deleted first v1.6.0 attempt's commit; this is the most recent maintainer attestation, but it does not cover the seven later commits and 16 changed paths in the published v1.6.0 tree or those installer changes, and its supporting transcript is not committed. **Current repository/release status (19 November 2026):** v1.6.0 is the latest published release (Release run #51), from exact tag/source commit `a5beea31d09d6ebbe1e974c7b58d66b3b46cf699`; GitHub records its source ZIP as 502,126 bytes with SHA-256 `034912aec7b8b587a71f5ab3816158eb1604fb4d1f8e9cda7dc5a0cd133fbf23`, independently re-hashed and reproduced byte-for-byte by the canonical packer from that commit. The historical pre-update main Normal CI #1649 [run 44560545993](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44560545993) passed 27 workflow-defined steps on the release SHA. `7f0f4f7e0bef8567811244f6632abc798c98983e` subsequently passed Normal CI #1655 [run 44576575377](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/44576575377), one commit before the v1.6.0 tag commit. The latest completed full-system build remains #21 [run 43982447714](https://github.com/kUmutUK/nixos-hyprland-vfio/actions/runs/43982447714), successful on exact source `672d255d4a921c097dd69eae817e8dc9699380d6`; GitHub compares Build #21 with the pre-update main base as 10 commits and 37 changed paths, and with current `main` as 17 commits and 38 changed paths. A fresh full-system build on updated `main` is required before the next release; Normal CI is not a substitute. Release #50's log records `TARGET_HOST_VALIDATED=true` accepted for exact commit `93b8929`, the deleted first v1.6.0 attempt's commit. This is a maintainer assertion of clean installation and host/Windows VM lifecycle checks, but the supporting host transcript is not in the repository; the older 16 November owner note that `install.sh` had not been tried predates this later declaration. Release #50 also received `VM_XML_VALIDATED=true`, but the XML did not change from v1.5.9 to v1.6.0, so the separate changed-XML gate did not trigger and this input is not proof of new Windows or NixOS `vdb` guest boots. Installed-NixOS guest boot/networking, saved-state/managed-save restore, and exact-source booted generation/kernel remain unverified in the retained technical record. **Locked input identities used by Build #21:** CachyOS kernel source `c9620070e884d55c5b5566e3fd46611ee24c4d3b`, its nested CachyOS Nixpkgs package set `82566dfe91ca5e12bc10b36272280628142f651d`, and root system `nixos-unstable` Nixpkgs `d4f25a3e562008648d45bcf2d70bcc7422cad84e` are distinct. The 19 November 2026 lock refresh (commit `2b7cfff3c2ef2f0d08a6b11a242d639c02e0846b`, uploaded via the web interface) advanced the current inputs to CachyOS `10e8df08ad828225575f448e6b49ae092132d9a8`, nested `nixos-unstable-small` Nixpkgs `d00708e733dc47417b440d7537b0349f1ee66e22`, and root Nixpkgs `04906337b6d53e8bb0eaf0470ae9f070a4d4eb55`; Build #21's identities above are now historical. Historical Build #19 used CachyOS `9df32f70be3550911f178b3ba9ad784996a4e80c` and root Nixpkgs `4d6a01a11146f4691c0991682885ad9e4686e3ee`.

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

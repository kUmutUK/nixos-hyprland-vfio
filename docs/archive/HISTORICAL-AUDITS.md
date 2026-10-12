# Historical audits — consolidated status

**Consolidation date:** 2026-10-12  
**Purpose:** preserve audit provenance and retractions without treating historical findings as current defects.

> Every report linked below is a snapshot of a specific prior ZIP/revision. File presence in an old report is not proof of a current bug. The current source tree and current runtime are authoritative. The `G`/retracted IDs in the 2026-10-12 consolidated review remain retracted and must not be reintroduced without new evidence.

## Source snapshots retained

| File | Snapshot | How to use it |
|---|---|---|
| `ANALIZ-2026-10-05-ZIP3-SUPERSEDED.md` | ZIP3 / 2026-10-05 | Historical investigation only; later edits superseded its open findings. |
| `nixos-hyprland-vfio-analiz-v2-SUPERSEDED.md` | ZIP2 / 2026-10-04 | Historical baseline; many described defects were fixed in later revisions. |
| `NIXOS-HYPRLAND-VFIO-ANALIZ.md` | early ZIP sequence / 2026-10-05 | Prior validation notes; do not apply commands without checking current source. |
| `DEGISIKLIKLER.md` | changes applied around 2026-10-05 | Historical changelog/decision record, not a current checklist. |
| `REMAINING-ISSUES-AUDIT-2026-10-09.md` | source ZIP / 2026-10-09 | Later historical audit; distinguish its static review from live-system tests. |
| `README.md` | archive index | Use this file to navigate the legacy reports. |

## Retraction discipline

- Retracted claims from the consolidated 2026-10-12 review must stay retracted unless new code or runtime evidence disproves the retraction.
- An item marked “fixed” in a prior report is not proof that the live deployed system contains that revision; check `git diff`, deployed XML, and runtime state as appropriate.
- An item marked “open” in an older snapshot is not automatically open today. Compare against the current source before changing code.
- Live-only matters remain explicitly unresolved until checked on the target host: the real swtpm directory/ownership at boot (`A3`), the installed `system.stateVersion` compatibility (`C14`), whether initrd `amdgpu` is required on the installed setup (`C17`), and availability of the selected OVMF NVRAM template (`C19`).

## Retraction register — G1 through G15

These 15 claims were explicitly retracted in the 2026-10-12 consolidated review.
They must not be revived as active findings without new evidence from the current
source or target machine.

| ID | Retracted claim | Reason it stays retracted |
|---|---|---|
| G1 | QEMU log rotation is absent and logs grow without bound. | Libvirt rotates/recreates the per-domain QEMU log on VM starts; no unbounded-log fix is justified by this claim. |
| G2 | A hyprlock label is duplicated. | Already corrected in release 1.3.3; re-check current source before alleging recurrence. |
| G3 | `cp -r` is redundant in `KURULUM.md`. | The alleged line is not present in the reviewed version. |
| G4 | `KURULUM.md` §9b has an unclosed code fence. | The code fence is properly closed in the reviewed version. |
| G5 | `install.sh` injects raw PCI input through `sed`. | PCI input is checked by `valid_pci()` and the XML sync uses Python, not raw `sed` interpolation. |
| G6 | `services.udev.packages = [ pkgs.libinput ]` is dead configuration. | It supplies the libinput udev rules, including `80-libinput-device-fixups.rules`; it is not an unused package. |
| G7 | An empty monitor name prevents Hyprland from starting. | The rule is valid catch-all syntax. It does not by itself mirror workspace 1; use a named output when a catch-all is not desired. |
| G8 | `services.steam` is an invalid NixOS option. | The source uses `programs.steam.enable`; the alleged `services.steam` option is not present. |
| G9 | The low-latency Vulkan layer `.so` cannot load. | Its manifest's `library_path` is an absolute Nix store path, which the Vulkan loader can open directly; PATH lookup is not required. |
| G10 | The `@gamemode` rule is dead. | It was removed in release 1.3.1; do not remove a rule that is no longer present. |
| G11 | `flake.lock` is non-canonical. | The reviewed lock file is canonical; the root `nixpkgs_2` node is expected and the impermanence node is absent. |
| G12 | `apply_var` escapes `$` incorrectly. | Its current escaping handles backslash, double quote, and `${`; a plain `$HOME` is not Nix interpolation. |
| G13 | Change OVMF NVRAM template to `edk2-x86_64-vars.fd`. | That filename is not present in the reviewed QEMU OVMF package inventory. Keep the current i386 template until the target host's `/run/libvirt/nix-ovmf/` files are checked (C19 remains live-only). |
| G14 | Unencrypted disk swap must be changed immediately. | The current design intentionally prioritizes zram (100) over disk swap (10); the residual disk-swap encryption risk is accepted/documented, not an unreviewed regression. |
| G15 | Looking Glass must be installed for the single-GPU VM. | Looking Glass requires a usable host display path and is not a general solution for this single-GPU passthrough design. |

## Current review scope

The 2026-10-12 maintenance pass updates static issues that can be resolved from source and documentation: qcow2 ownership instructions, generated VM UUID/MAC, optional diagnostic VNC XML generation, guest audio-device duplication, greetd environment transfer, WuWa model preflight, fuser variable names, script modes, installer backup retention, stale monitor documentation, dead Waybar/MPRIS entries, command PATH pinning, and parameter cost documentation.

The maintenance pass does **not** claim that a NixOS evaluation/build or real RX 6700 XT passthrough cycle succeeded. Use `CHANGELOG.md` for the exact files changed in the current pass and run the repository's CI gates before deployment.

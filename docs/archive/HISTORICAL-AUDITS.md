# Historical audits — consolidated status

**Consolidated:** 2026-10-15

These reports describe specific past snapshots. An item marked open in an old report is not automatically a defect in the current tree. Conversely, a historical item marked fixed does not prove a deployed machine has the fix. Inspect the current source and runtime before acting.

## Retraction register

The 2026-10-12 review explicitly retracted the following claims. Do not revive them without new evidence:

| ID | Retracted claim | Reason |
|---|---|---|
| G1 | QEMU logs grow without bound because rotation is absent. | Libvirt recreates/rotates per-domain QEMU logs on VM starts. |
| G2 | A Hyprlock label is duplicated. | The label was corrected in a later release. |
| G3 | `cp -r` is redundant in `KURULUM.md`. | The reported line was not present in the reviewed snapshot. |
| G4 | `KURULUM.md` has an unclosed code fence. | The fence was closed in the reviewed version. |
| G5 | The installer injects raw PCI input through `sed`. | Current PCI input is validated, and XML synchronization uses Python. |
| G6 | `services.udev.packages = [ pkgs.libinput ]` is dead configuration. | It supplies libinput udev rules. |
| G7 | An empty Hyprland monitor name prevents startup. | The syntax is valid catch-all syntax; choose an explicit output if desired. |
| G8 | `services.steam` is used as an invalid option. | The configuration uses `programs.steam.enable`. |
| G9 | The low-latency Vulkan layer cannot load because it is not on PATH. | Its manifest uses an absolute Nix store path. |
| G10 | The `@gamemode` rule is dead. | It had already been removed. |
| G11 | `flake.lock` is non-canonical due to the absent impermanence input. | The later reviewed lock was canonical and had no impermanence node. |
| G12 | `apply_var` mishandles plain `$HOME`. | A plain dollar sign is not Nix interpolation; the current escaping handles `${`. |
| G13 | Replace the OVMF NVRAM file with an unverified filename. | Keep the configured template until the target host's installed OVMF inventory is checked. |
| G14 | Unencrypted disk swap must be changed as an immediate code defect. | The residual encryption risk is documented and must be considered as a system-security decision. |
| G15 | Looking Glass is mandatory for single-GPU passthrough. | It is not a universal solution when the host has no display path. |

## Items that still require the target host

The following cannot be certified from static files alone: actual OVMF variable-template availability, the effective `system.stateVersion` on an existing installation, whether initrd amdgpu loading is needed on the deployed system, swtpm directory ownership at boot, and a complete RX 6700 XT passthrough/recovery cycle.

## Current source status

The current maintenance package additionally corrects the Windows VM Q35 alias and ISO priority, improves handling of failed Ollama API responses, and switches the CachyOS kernel input to its upstream `release` branch with the pinned overlay. The checked-in `flake.lock` already pins that input; do not refresh it just to apply these fixes. Run `nix flake lock --update-input cachyos-kernel` only when intentionally updating the kernel input, then review and retain the lock-file diff. See the root `CHANGELOG.md` and `docs/REPAIR-AND-VALIDATION-REPORT.md`.

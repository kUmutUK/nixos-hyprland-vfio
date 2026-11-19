# Template for a new host directory: copy to nixos/hosts/<machine-name>/ and
# fill in every marked value. Do NOT deploy this template as-is.
#
# New-host checklist (adapted from the reference host):
#  1. Generate hardware-configuration.nix ON THE TARGET MACHINE:
#       sudo nixos-generate-config --show-hardware-config
#     Save the output as nixos/hosts/<machine-name>/hardware-configuration.nix.
#     Never reuse the reference host's file: its Btrfs/LUKS/ESP/swap UUIDs and
#     the Home Snapper @home/.snapshots subvolume layout belong to that machine.
#  2. Review the AMD assumptions inherited from the reference configuration:
#     - kvm-amd, amd_pstate=active, AMD microcode
#     - RX 6700 XT native target: gfx1031; configured ROCm compatibility override
#       `rocmOverrideGfx = "10.3.0"` selects gfx1030 (not the GPU's native identity)
#     - RADV Vulkan environment and amdgpu initrd module
#     An Intel/NVIDIA machine needs these blocks adapted or removed.
#  3. VFIO is single-GPU passthrough to the win10 guest. If this host does not
#     do passthrough, remove the virtualization module usage and the hook
#     directory; the QEMU hook filters on TARGET_VM="win10".
#  4. Copy host-settings.nix from nixos/hosts/nixos/ and set:
#     monitorOutput (hyprctl monitors name), monitorMode, wallpaperVideo,
#     gitName, gitEmail.
#  5. Register the host in nixos/flake.nix:
#       nixosConfigurations.<machine-name> = nixpkgs.lib.nixosSystem { ... }
#     and point its module import at ./hosts/<machine-name>/configuration.nix.
#  6. Keep system.stateVersion at the FIRST NixOS release installed on this
#     machine; never advance it to track nixpkgs.
{
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "26.05"; # set to the machine's actual baseline

  imports = [
    ./hardware-configuration.nix
    ./host-settings.nix
    # Add shared modules here as the module library grows, e.g.:
    # (../../modules/nixos/security.nix)
  ];

  networking.hostName = "<machine-name>";

  # Minimal placeholders so the template evaluates conceptually; replace every
  # value with the target machine's real settings before building.
}

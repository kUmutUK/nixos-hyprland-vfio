# flake.nix
{
  description = "NixOS CachyOS RT-Bore-LTO Kernel — Gaming + Hyprland + VFIO";

  # Configure the Nix Community binary cache at flake-evaluation time for
  # supported packages. This is not the CachyOS kernel cache: the selected
  # RT-Bore-LTO ThinLTO variant is not published upstream and builds locally.
  # Review the URL and public key before accepting; do not bypass the prompt
  # with --accept-flake-config merely to suppress it.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/master";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Keep Hyprland and its companion packages on the same nixpkgs input.
    # A separate version-pinning overlay can create ABI mismatches between
    # Hyprland and clients built against the system package set.
    lsfg-vk-flake.url = "github:pabloaul/lsfg-vk-flake/main";
    lsfg-vk-flake.inputs.nixpkgs.follows = "nixpkgs";
    # Impermanence is intentionally not imported: this configuration does
    # not define a persistent-storage layout. Reintroduce the input only
    # together with matching environment.persistence and Home Manager settings.
  };

  outputs =
    {
      nixpkgs,
      cachyos-kernel,
      home-manager,
      lsfg-vk-flake,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          lsfg-vk-flake.nixosModules.default

          ({ pkgs, ... }: {
            nixpkgs.config.allowUnfree = true;
            # Keep the CachyOS kernel and patch set on the upstream pinned nixpkgs revision.
            # The package follows the `master` input; its kernel version is not hard-coded here.
            # Update the flake lock intentionally with `nix flake update cachyos-kernel` when
            # upstream publishes a newer kernel. RT-Bore-LTO LTO is not in the binary cache,
            # so this variant is expected to build locally even with `pinned`.
            nixpkgs.overlays = [ cachyos-kernel.overlays.pinned ];
            boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-rt-bore-lto;
            # Hyprland, its companion tools, and xdg-desktop-portal-hyprland
            # come from the same nixpkgs revision to keep their ABI consistent.
            # Keep shared system packages declared in configuration.nix only;
            # duplicate declarations here make ownership harder to maintain.
          })
          ./configuration.nix
        ];
      };

      # Expose the selected LSFG-VK v1 package so CI and contributors can build it directly.
      packages.${system}.lsfg-vk = lsfg-vk-flake.packages.${system}.lsfg-vk;

      # The README uses `nix develop`; expose one flake dev shell rather than a
      # separate legacy channel-based shell.
      devShells.${system}.default = pkgs.mkShell {
        name = "nixos-hyprland-vfio";
        packages = with pkgs; [
          # Use nixfmt; nixfmt-rfc-style is deprecated and aliases this package.
          nixfmt
          python3
          statix
          deadnix
          shellcheck
          nix-output-monitor
          git
          coreutils
          pciutils
          curl
          jq
          libxml2
        ];
        shellHook = ''
          echo "nixos-hyprland-vfio development shell — nixfmt, Python, statix, and deadnix are available"
        '';
      };
    };
}

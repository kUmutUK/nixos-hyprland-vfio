# flake.nix
{
  description = "NixOS CachyOS BORE Kernel – Gaming + pyprland + lsfg-vk";

  # Configure the CachyOS binary cache at flake-evaluation time. On a fresh
  # installation, accept this cache explicitly with --accept-flake-config.
  nixConfig = {
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
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

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, lsfg-vk-flake, ... }:
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
          # Use the upstream pinned overlay so the kernel derivation uses the
          # same nixpkgs revision as the published binary cache. The default
          # overlay can miss the cache and trigger a local ThinLTO kernel build.
          nixpkgs.overlays = [ cachyos-kernel.overlays.pinned ];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto;
          # Hyprland, its companion tools, and xdg-desktop-portal-hyprland
          # come from the same nixpkgs revision to keep their ABI consistent.
          # Keep shared system packages declared in configuration.nix only;
          # duplicate declarations here make ownership harder to maintain.
        })
        ./configuration.nix
      ];
    };

    # The README uses `nix develop`; expose one flake dev shell rather than a
    # separate legacy channel-based shell.
    devShells.${system}.default = pkgs.mkShell {
      name = "nixos-hyprland-vfio";
      packages = with pkgs; [
            # Use nixfmt; nixfmt-rfc-style is deprecated and aliases this package.
            nixfmt
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
        echo "nixos-hyprland-vfio development shell — nixfmt, statix, and deadnix are available"
      '';
    };
  };
}

# flake.nix
{
  description = "NixOS CachyOS RT-Bore-LTO x86-64-v3 Kernel — Gaming + Hyprland + VFIO";

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
    # Reuse the kernel flake's exact Nixpkgs input when regenerating its package set.
    cachyos-nixpkgs.follows = "cachyos-kernel/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Impermanence is intentionally not imported: this configuration does
    # not define a persistent-storage layout. Reintroduce the input only
    # together with matching environment.persistence and Home Manager settings.
  };

  outputs =
    {
      nixpkgs,
      cachyos-kernel,
      cachyos-nixpkgs,
      home-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Keep kernel and out-of-tree module derivations on the exact Nixpkgs revision
      # used by nix-cachyos-kernel's pinned overlay.
      cachyosPkgs = import cachyos-nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowInsecurePredicate = _: true;
        };
      };
      cachyosKernelHelpers = cachyosPkgs.callPackage "${cachyos-kernel}/helpers.nix" { };
      rtBoreLtoV3Kernel = cachyos-kernel.legacyPackages.${system}.linux-cachyos-rt-bore-lto.override {
        processorOpt = "x86_64-v3";
      };
      rtBoreLtoV3KernelPackages = cachyosKernelHelpers.kernelModuleLLVMOverride (
        cachyosPkgs.linuxKernel.packagesFor rtBoreLtoV3Kernel
      );
      # LSFG-VK v2 is licensed CC BY-NC-ND 4.0, so allow it explicitly for this
      # standalone package output while keeping the main package set unchanged.
      pkgsUnfree = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      lsfgVkV2Package = pkgsUnfree.callPackage ./lsfg-vk-v2.nix { };
      makoRendererPackage = pkgs.callPackage ./mako-renderer.nix { };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            nixpkgs.config.allowUnfree = true;
            # Build reference-host userland C/C++ packages for x86-64-v3 and tune
            # them for its Zen 3 Ryzen 5 5600 CPU. This generation is not portable
            # to CPUs without x86-64-v3 support.
            nixpkgs.hostPlatform = {
              inherit system;
              gcc = {
                arch = "x86-64-v3";
                tune = "znver3";
              };
            };
            # Keep CachyOS kernel source/patches and the module set on the exact
            # Nixpkgs revision used by the kernel flake. RT-Bore, RT, and ThinLTO
            # remain enabled; only the kernel CPU baseline is raised.
            nixpkgs.overlays = [ cachyos-kernel.overlays.pinned ];
            boot.kernelPackages = rtBoreLtoV3KernelPackages;
            # Hyprland, its companion tools, and xdg-desktop-portal-hyprland
            # come from the same nixpkgs revision to keep their ABI consistent.
            # Keep shared system packages declared in configuration.nix only;
            # duplicate declarations here make ownership harder to maintain.
          })
          ./configuration.nix
        ];
      };

      # Expose the pinned LSFG-VK v2 and optional MAKO Renderer packages for CI/contributors.
      packages.${system} = {
        lsfg-vk-v2 = lsfgVkV2Package;
        mako-renderer = makoRendererPackage;
      };

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
          lua
        ];
        shellHook = ''
          echo "nixos-hyprland-vfio development shell — nixfmt, Python, statix, and deadnix are available"
        '';
      };
    };
}

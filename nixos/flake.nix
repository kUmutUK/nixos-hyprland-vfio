# flake.nix
{
  description = "NixOS CachyOS RT-Bore-LTO x86-64-v3 Kernel — Gaming + Hyprland + VFIO";

  # Configure binary caches at flake-evaluation time: this project's own
  # Cachix cache (live since 24 November 2026) publishes the selected
  # RT-Bore-LTO kernel and its runtime closure — the one component no
  # upstream cache serves — and the Nix Community cache covers supported
  # packages. Review the URLs and public keys before accepting; do not
  # bypass the prompt with --accept-flake-config merely to suppress it.
  nixConfig = {
    extra-substituters = [
      "https://kumutuk-nixos-hyprland-vfio.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "kumutuk-nixos-hyprland-vfio.cachix.org-1:wgWsd619A9+2Mj+iEDABPbnIB1YqJnVJWt2D7Bv9JTQ="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
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
      # Keep unfree kernel dependencies enabled, but retain Nixpkgs' default
      # rejection of insecure packages. If the pinned kernel closure ever needs
      # an insecure dependency, add a named, justified exception rather than a
      # catch-all predicate for the entire CachyOS package set.
      cachyosPkgs = import cachyos-nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      cachyosKernelHelpers = cachyosPkgs.callPackage "${cachyos-kernel}/helpers.nix" { };
      rtBoreLtoV3KernelFor = kcfi: cachyos-kernel.legacyPackages.${system}.linux-cachyos-rt-bore-lto.override {
        processorOpt = "x86_64-v3";
        bbr3 = true;
        inherit kcfi;
      };
      rtBoreLtoV3KernelPackagesFor = kcfi: cachyosKernelHelpers.kernelModuleLLVMOverride (
        cachyosPkgs.linuxKernel.packagesFor (rtBoreLtoV3KernelFor kcfi)
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
          ({ pkgs, config, ... }: {
            nixpkgs.config.allowUnfree = true;
            # Keep the NixOS userland on the generic x86_64-linux baseline so
            # ordinary system packages can use standard x86-64 binary substitutes.
            # The x86-64-v3 target is deliberately limited to the RT-Bore-LTO
            # kernel derivation above; that kernel still requires a v3-capable CPU.
            nixpkgs.hostPlatform = system;
            # Keep CachyOS kernel source/patches and the module set on the exact
            # Nixpkgs revision used by the kernel flake. RT-Bore, RT, and ThinLTO
            # remain enabled; only the kernel CPU baseline is raised.
            nixpkgs.overlays = [ cachyos-kernel.overlays.pinned ];
            boot.kernelPackages = rtBoreLtoV3KernelPackagesFor config.kumutuk.host.kernelKcfi;
            # Hyprland, its companion tools, and xdg-desktop-portal-hyprland
            # come from the same nixpkgs revision to keep their ABI consistent.
            # Keep shared system packages declared in configuration.nix only;
            # duplicate declarations here make ownership harder to maintain.
          })
          ./hosts/nixos/configuration.nix
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
          # pre-commit runs .pre-commit-config.yaml; its local hooks reuse the
          # tools above from this shell, so no hook downloads its own.
          pre-commit
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

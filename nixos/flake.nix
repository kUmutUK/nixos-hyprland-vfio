# flake.nix
{
  description = "NixOS CachyOS RT-Bore-LTO x86-64-v3 Kernel — Gaming + Hyprland + VFIO";

  # Publish the binary-cache endpoints to flake consumers. Signing trust is
  # deliberately not configured here: trusted-public-keys is a restricted
  # daemon setting and belongs in root-managed nix.settings in
  # hosts/nixos/configuration.nix, not in a client-supplied flake config.
  # This avoids asking an untrusted user process to modify the
  # daemon's trust policy.
  nixConfig = {
    extra-substituters = [
      "https://kumutuk-nixos-hyprland-vfio.cachix.org"
      "https://nix-community.cachix.org"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    # Reuse the kernel flake's exact Nixpkgs input when regenerating its package set.
    cachyos-nixpkgs.follows = "cachyos-kernel/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Serpantinum desktop shell (bar, notifications, launcher, clipboard,
    # dock, PipeWire audio engine, and gamma daemon). Its Nixpkgs input is
    # deliberately NOT followed from the root system: the shell builds
    # against the Quickshell/Qt revision upstream tests, while the host keeps
    # its own nixos-unstable userland. See docs/SERPANTINUM.md.
    serpantinum.url = "github:ilyamiro/serpantinum";
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
      serpantinum,
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
      rtBoreLtoV3KernelFor =
        kcfi:
        cachyos-kernel.legacyPackages.${system}.linux-cachyos-rt-bore-lto.override {
          processorOpt = "x86_64-v3";
          bbr3 = true;
          inherit kcfi;
        };
      rtBoreLtoV3KernelPackagesFor =
        kcfi:
        cachyosKernelHelpers.kernelModuleLLVMOverride (
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
      heliumPackage = pkgs.callPackage ./helium.nix { };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          # Serpantinum system module: registers the PAM service its lock
          # screen authenticates against, enables Ski as the default file
          # manager, and defaults the shared prerequisites (NetworkManager,
          # Bluetooth, i2c, PipeWire, rtkit, power-profiles-daemon, and the
          # nerd-fonts.iosevka glyph font). Everything it sets uses
          # mkDefault, so the explicit values in configuration.nix win.
          serpantinum.nixosModules.default
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
            # home.nix imports serpantinum.homeManagerModules.default through
            # this extraSpecialArgs entry; standalone Home Manager use (no
            # flake in scope) degrades to the previous shell-less setup via
            # the `serpantinum ? null` guard in home.nix.
            home-manager.extraSpecialArgs = { inherit serpantinum; };
          })
          ./hosts/nixos/configuration.nix
        ];
      };

      # Expose the pinned LSFG-VK v2 and optional MAKO Renderer packages for CI/contributors.
      packages.${system} = {
        lsfg-vk-v2 = lsfgVkV2Package;
        mako-renderer = makoRendererPackage;
        helium = heliumPackage;
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

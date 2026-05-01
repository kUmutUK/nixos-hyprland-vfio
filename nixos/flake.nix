{
  description = "NixOS CachyOS BORE Kernel – Gaming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    # hyprland-plugins artık kullanılmadığı için input kaldırıldı.
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, hyprland, ... }:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;

      modules = [
        home-manager.nixosModules.home-manager

        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            cachyos-kernel.overlays.default
            (final: prev: {
              hyprland = hyprland.packages.${system}.hyprland;
              # hyprland-plugins overlay gereksiz, kaldırıldı.
            })
          ];

          boot.kernelPackages =
            pkgs.cachyosKernels.linuxPackages-cachyos-bore;

          # Hyprland'ı flake'ten al (overlay'den)
          programs.hyprland.package = pkgs.hyprland;

          services.xserver.videoDrivers = [ "amdgpu" ];
        })

        ./configuration.nix
      ];
    };
  };
}

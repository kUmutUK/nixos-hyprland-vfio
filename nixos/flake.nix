{
  description = "NixOS CachyOS BORE Kernel – Gaming + hyprexpo (nixpkgs) + pyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
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
            })
          ];

          boot.kernelPackages =
            pkgs.cachyosKernels.linuxPackages-cachyos-bore;

          programs.hyprland.package = pkgs.hyprland;

          services.xserver.videoDrivers = [ "amdgpu" ];

          # pyprland sistem genelinde kullanılabilir
          environment.systemPackages = [ pkgs.pyprland ];
        })

        ./configuration.nix
      ];
    };
  };
}

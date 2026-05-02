{
  description = "NixOS CachyOS BORE Kernel – Gaming + pyprland + Millennium";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    
    # Millennium girdisi
    millennium = {
      url = "github:SteamClientHomebrew/Millennium?dir=packages/nix";
    };
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, hyprland, millennium, ... }:
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
            # Millennium overlay'ı
            millennium.overlays.default
          ];

          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
          programs.hyprland.package = pkgs.hyprland;
          services.xserver.videoDrivers = [ "amdgpu" ];

          environment.systemPackages = [ 
            pkgs.pyprland
            pkgs.millennium-steam  # ← Steam yerine Millennium'lu sürümü kullan
          ];
        })

        ./configuration.nix
      ];
    };
  };
}

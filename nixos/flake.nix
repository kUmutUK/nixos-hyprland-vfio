# flake.nix
{
  description = "NixOS CachyOS BORE Kernel – Gaming + pyprland + lsfg-vk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland/v0.55.0";
    lsfg-vk-flake.url = "github:pabloaul/lsfg-vk-flake/main";
    lsfg-vk-flake.inputs.nixpkgs.follows = "nixpkgs";
    
    # ⭐ Bu girdiyi ekle:
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, hyprland, lsfg-vk-flake, impermanence, ... }:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        home-manager.nixosModules.home-manager
        lsfg-vk-flake.nixosModules.default
        
        # ⭐ Modülü burada içe aktar:
        impermanence.nixosModules.impermanence
        
        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            cachyos-kernel.overlays.default
            (final: prev: {
              hyprland = hyprland.packages.${system}.hyprland;
            })
          ];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
          programs.hyprland.package = pkgs.hyprland;
          environment.systemPackages = [ pkgs.pyprland ];
        })
        ./configuration.nix
      ];
    };
  };
}

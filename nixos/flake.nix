{
  description = "NixOS CachyOS BORE Kernel – Gaming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, ... }:
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
          nixpkgs.overlays = [ cachyos-kernel.overlays.default ];

          boot.kernelPackages =
            pkgs.cachyosKernels.linuxPackages-cachyos-bore;

          services.xserver.videoDrivers = [ "amdgpu" ];
        })

        ./configuration.nix
      ];
    };
  };
}

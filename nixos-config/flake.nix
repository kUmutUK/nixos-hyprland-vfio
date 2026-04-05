{
  description = "NixOS CachyOS BORE Kernel – Gaming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
  };

  outputs = { self, nixpkgs, cachyos-kernel, ... }:
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ cachyos-kernel.overlays.default ];

          # BORE kernel (LTO YOK)
          boot.kernelPackages =
            pkgs.cachyosKernels.linuxPackages-cachyos-bore;

          services.xserver.videoDrivers = [ "amdgpu" ];
        })
        ./configuration.nix
      ];
    };
  };
}

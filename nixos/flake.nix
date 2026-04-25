{
  description = "NixOS CachyOS BORE Kernel – Gaming";

  inputs = {
    # nixos-unstable: 26.05 Mayıs 2026'da çıkacak; cachyos-kernel overlay
    # da unstable hedefler. 26.05 çıkınca nixos-26.05 yapılabilir.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";

    # nixpkgs unstable ile uyumlu home-manager (release-26.05 henüz yok).
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

          # services.xserver.enable = false olmasına rağmen bu satır gereklidir:
          # NixOS bu ayarı amdgpu KMS kernel parametresi ve udev kuralları için
          # kullanır (xserver olmadan da). hardware.graphics.enable = true ile
          # birlikte tam GPU desteğini sağlar.
          services.xserver.videoDrivers = [ "amdgpu" ];
        })

        ./configuration.nix
      ];
    };
  };
}

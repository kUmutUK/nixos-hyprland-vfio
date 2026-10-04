# flake.nix
{
  description = "NixOS CachyOS BORE Kernel – Gaming + pyprland + lsfg-vk";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # ⚠️ Hyprland overlay'i KALDIRILDI.
    # Önceden `hyprland.url = "github:hyprwm/Hyprland/v0.55.0"` ile Hyprland
    # 0.55.0 zorlanıyordu. Nixpkgs (nixos-unstable) ise 0.54.3 veriyordu —
    # yani compositor 1 minor İLERİDE, hyprlock 0.9.5 / hypridle 0.1.7 /
    # hyprpicker 0.4.6 / hyprpolkitagent 0.1.3 / xdg-desktop-portal-hyprland
    # 1.3.12 ise 0.54.3'e derlenmişti: 0.54-ABI'lı istemciler 0.55
    # compositor'a konuşuyordu (özellikle portal sessizce hiçbir şey sunmayabilir).
    # Artık tüm Hyprland ailesi tek nixpkgs'ten geliyor → ABI tutarlı.
    # (Geri almak isterseniz: aşağıdaki overlay bloğunu geri açın.)
    lsfg-vk-flake.url = "github:pabloaul/lsfg-vk-flake/main";
    lsfg-vk-flake.inputs.nixpkgs.follows = "nixpkgs";
    
    # ⭐ Bu girdiyi ekle:
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, lsfg-vk-flake, impermanence, ... }:
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
          ];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
          # hyprland, hyprlock, hypridle, hyprpicker, hyprpolkitagent ve
          # xdg-desktop-portal-hyprland hepsi aynı nixpkgs rev'inden gelir.
          programs.hyprland.package = pkgs.hyprland;
          environment.systemPackages = [ pkgs.pyprland ];
          # home.persistence (home.nix) çalışması için ekstra bir şey
          # yapmaya gerek yok: home-manager.nixosModules.home-manager zaten
          # yukarıda import edildiğinden, impermanence.nixosModules.impermanence
          # kendi Home Manager modülünü home-manager.sharedModules'e otomatik
          # ekliyor (bkz. impermanence/nixos.nix). impermanence.homeManagerModules.impermanence'i
          # elle import ETMEYİN — o yol artık deprecated ve sadece
          # "assertion = false" içeriyor, elle eklerse build'i kırar.
        })
        ./configuration.nix
      ];
    };
  };
}

# flake.nix
{
  description = "NixOS CachyOS BORE Kernel – Gaming + pyprland + lsfg-vk";

  # Düzeltme (2026-10-04): substituters/trusted-public-keys yalnızca
  # configuration.nix içindeki nix.settings ile veriliyordu. Bu ayarlar
  # FLAKE değerlendirildiğinde henüz uygulanmadığı için `nixos-install` ve
  # ilk `nixos-rebuild` CachyOS kernel'ini büyük olasılıkla kaynaktan deriyordu.
  # Buraya da ekleyip kullanımda `--accept-flake-config` gerektiğini not ediyoruz.
  nixConfig = {
    extra-substituters = [
      "https://xddxdd.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

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
    pkgs = nixpkgs.legacyPackages.${system};
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

    # Düzeltme (2026-10-04): README `nix develop` diyordu ama flake'te
    # devShells output'u yoktu; kökte ayrı bir `shell.nix` (<nixpkgs> channel
    # yaklaşımı) vardı. İki ayrı development modeli yerine tek gerçek devShell.
    devShells.${system}.default = pkgs.mkShell {
      name = "nixos-hyprland-vfio";
      packages = with pkgs; [
            nixfmt-rfc-style
            statix
            deadnix
            shellcheck
            nix-output-monitor
            git
            coreutils
            pciutils
            curl
            jq
            libxml2
          ];
      shellHook = ''
        echo "nixos-hyprland-vfio dev shell — nixfmt-rfc-style, statix, deadnix hazir"
      '';
    };
  };
}

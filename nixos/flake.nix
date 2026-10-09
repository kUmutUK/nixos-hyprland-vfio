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
    # ⚠️ Hyprland overlay'i KALDIRILDI (karar hâlâ doğru, GEREKÇE bayat).
    # Kararın eski gerekçesi: nixpkgs 0.54.3 veriyordu, overlay 0.55.0'a
    # zorluyordu, istemciler 0.54 ABI ile derlenmişti -> ABI karışıklığı.
    #
    # DÜZELTME (2026-10-05): kilitli nixpkgs rev'i 7a0f122'de Hyprland
    # 0.56.2'dir, yani artık nixpkgs overlay'in sürümünden YENİ. Buna rağmen
    # overlay'in kaldırılmış olması DOĞRU KARARDIR: tek nixpkgs rev'i her
    # zaman ABI tutarlılığı garantisi verir, sabitlenmiş bir sürüm ise
    # istemcileri geride bırakabilir. Sadece yukarıdaki gerekçe artık
    # geçerli değil.
    #
    # Doğrulanan sürümler (kilitli rev 7a0f122f5090):
    #   hyprland 0.56.2 · hyprlock 0.9.6 · hypridle 0.1.8 · hyprpicker 0.4.7
    #   hyprpolkitagent 0.1.3
    lsfg-vk-flake.url = "github:pabloaul/lsfg-vk-flake/main";
    lsfg-vk-flake.inputs.nixpkgs.follows = "nixpkgs";
    # ⚠️ impermanence girdisi ve modülü KALDIRILDI (2026-10-09) — bu config
    # kalıcı depolama kullanmıyor, kasıtlı olarak. Gerekçe ve geri açma
    # reçetesi: configuration.nix → "Kalıcı depolama (impermanence)" notu.
    # Özet: home.persistence yorumdaydı, environment.persistence hiç
    # tanımlanmadıydı; modülün tek ürettiği her rebuild'de basılan uyarıydı.
  };

  outputs = { self, nixpkgs, cachyos-kernel, home-manager, lsfg-vk-flake, ... }:
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

        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            cachyos-kernel.overlays.default
          ];
          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore;
          # hyprland, hyprlock, hypridle, hyprpicker, hyprpolkitagent ve
          # xdg-desktop-portal-hyprland hepsi aynı nixpkgs rev'inden gelir.
          programs.hyprland.package = pkgs.hyprland;
          # DÜZELTME (2026-10-06): `environment.systemPackages = [ pkgs.pyprland ]`
          # burada kaldırıldı. pyprland ZATEN `configuration.nix` →
          # `environment.systemPackages` listesinde tanımlıydı; buradaki ikinci
          # tanım aynı paketi iki kez PATH'e ekliyordu. CHANGELOG [1.3.1]
          # tekrarın "temizlendiğini" kaydetmişti ama bu satır duruyordu.
          # Tek kaynak: configuration.nix.
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
            # P2-2: nixfmt-rfc-style artık deprecated ("same as pkgs.nixfmt")
            nixfmt
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
        echo "nixos-hyprland-vfio dev shell — nixfmt, statix, deadnix hazir"
      '';
    };
  };
}

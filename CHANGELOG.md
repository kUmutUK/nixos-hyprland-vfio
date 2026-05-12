# Sürüm Notları (Changelog)

Bu dosya, NixOS Hyprland VFIO projesindeki tüm önemli değişiklikleri sürüm bazında listeler.
Proje, [Keep a Changelog](https://keepachangelog.com/tr/1.0.0/) biçimini temel alır ve 
[Semantic Versioning](https://semver.org/lang/tr/) kurallarına uyar.

## [1.0.0] – 2026-05-12
### Eklenenler
- **VFIO (GPU Passthrough)**: Tek AMD GPU’nun Windows VM’e dinamik olarak devredilmesini 
  sağlayan libvirt hook mekanizması (`hooks/qemu`). Looking Glass desteği.
- **CachyOS BORE Kernel**: Düşük gecikme ve oyun performansı için özel kernel.
- **Hyprland 0.55.0**: Wayland tabanlı, animasyonlu ve tamamen özelleştirilmiş pencere yöneticisi.
- **Catppuccin Tema Entegrasyonu**: GTK, Hyprland, Kitty, Waybar, btop ve fzf gibi tüm 
  bileşenlerde tutarlı renk paleti.
- **Canlı Duvar Kağıdı Desteği**: `mpvpaper` ile video duvar kağıdı. `mpvpaper-watchdog` 
  sayesinde tam ekran uygulamalarda otomatik durdurma/başlatma.
- **Dinamik Kısayol Pencereleri**: `pyprland` ile terminal (`scratchterm`), müzik ve dosya 
  yöneticisi için çabuk erişim.
- **Oyun Optimizasyonları**: GameMode (CPU/GPU önceliği, duvar kağıdı kontrolü), Ananicy 
  (CachyOS kuralları), MangoHud ve Gamescope desteği.
- **Yapay Zeka (AI)**: AMD GPU üzerinde çalışan Ollama (ROCm) entegrasyonu.
- **Güvenlik**: AppArmor zorunlu erişim kontrolü, Fail2ban SSH koruması, 
  parola girişi kapalı SSH yapılandırması.
- **Sistem Bakımı**: Otomatik Nix çöp toplama, Btrfs scrub, Snapper anlık görüntüleri, 
  zramSwap ve logrotate.
- **Detaylı Dokümantasyon**: Türkçe `KURULUM.md` (LUKS+Btrfs adımlarıyla), 
  `CONTRIBUTING.md`, `install.sh` otomatik kurulum betiği ve GitHub Actions CI.
- **Kapsamlı CLI Deneyimi**: Fish shell, Starship, Zoxide, fzf, eza, bat ve bolca alias.

### Değişiklikler
- Sistem temeli NixOS 26.05 (Yarara) olarak güncellendi.
- `dbus-broker` ve `initrd`’de `systemd` etkinleştirildi.
- Hyprland yapılandırması v0.55.0 uyumlu hale getirildi.

### Düzeltmeler
- İlk kararlı sürüm. Önceki beta sürümlerinden gelen tüm bilinen hatalar giderildi.

[1.0.0]: https://github.com/kUmutUK/nixos-hyprland-vfio/releases/tag/v1.0.0

# 📜 Changelog

Tüm önemli değişiklikler bu dosyada belgelenmiştir.

---

## [2.0.0] – 2026-05-06

### ✨ Eklenenler

* Güvenli `install.sh`: GPU PCI adresleri, monitör, git bilgileri gibi değişkenleri soran ve dosyalara işleyen etkileşimli betik
* Kapsamlı `README.md`: özellikler, kurulum, kullanım, donanım uyarlama ve SSS
* Türkçe kurulum rehberi (`KURULUM.md`)
* `LICENSE` (MIT), `.gitignore`, `CONTRIBUTING.md`, `CHANGELOG.md`
* GitHub Actions CI (`.github/workflows/check.yml`) – her commit'te `nix flake check`
* Geliştirme kabuğu (`shell.nix`)

---

### 🔧 Değişiklikler

* GPU PCI adresleri ve monitör çıkışı `configuration.nix` ve `home.nix` içinde `let` bloklarıyla değişkenleştirildi
* `amdgpu.ppfeaturemask`:

  * `0xffffffff` → `0xfffd7fff` (daha güvenli)
* VFIO hook iyileştirildi:

  * `sleep 5` kaldırıldı
  * yerine `fuser /dev/dri/card0` ile GPU serbest kalma kontrolü eklendi
* Hyprland 0.54 ile uyumsuz `blur { ... }` bloğu kaldırıldı
* Git bilgileri ve mpvpaper video yolu `home.nix` içinde değişken yapıldı
* `install.sh`, riskli `sed` işlemlerinden arındırıldı

---

### 🐞 Düzeltmeler

* README’de hatalı parola bilgisi düzeltildi (`hashedPasswordFile`)
* Intel / NVIDIA donanım uyarlama talimatları iyileştirildi
* `flake.nix` içinde Hyprland sürümü `v0.54.0` olarak sabitlendi

---

## [1.0.0] – 2026-04-??

### 🎉 İlk Sürüm

* CachyOS BORE kernel
* Hyprland masaüstü
* Oyun optimizasyonları
* VFIO GPU passthrough
* Home-Manager ile tam entegre dotfile yönetimi

---

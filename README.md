# 🧊 NixOS Hyprland Gaming + VFIO Config (AMD Optimized)

> ⚠️ **Bu bir başlangıç seviyesi kurulum değildir.** Flake, Wayland ve sistem seviyesi yapılandırma konusunda deneyim gerektirir.

Günlük Linux kullanımı ile Windows VM'i aynı makinede, neredeyse native performansla çalıştırmak için tasarlanmış tam deklaratif NixOS yapılandırması.

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
</p>

---

## 🎯 Bu Setup Ne Yapıyor?

Birçok Hyprland config yalnızca görselliğe odaklanır. Bu yapılandırma üçünü bir arada sunar:

- 🖥️ Temiz Wayland masaüstü (Hyprland + Catppuccin Mocha)
- 🎮 AMD optimize oyun performansı (RADV, GameMode, MangoHud, Gamescope)
- 🧠 GPU passthrough — Linux'ta çalışırken Windows VM'e fiziksel GPU ver

→ Hepsini tek bir deklaratif NixOS sisteminde

---

## 💻 Test Edilen Donanım

| Bileşen    | Model                   |
|------------|-------------------------|
| CPU        | AMD Ryzen 5 5600        |
| GPU        | AMD Radeon RX 6700 XT   |
| RAM        | 32GB DDR4               |
| Depolama   | NVMe SSD                |
| Mimari     | x86_64-linux            |

---

## ⚡ Temel Özellikler

### 🐧 Çekirdek
- **CachyOS BORE Kernel** — gaming ve düşük latency için optimize edilmiş scheduler
- `amd_pstate=guided` — AMD P-state frekans yönetimi
- `iommu=pt + amd_iommu=on` — VFIO için IOMMU passthrough modu
- `hugepagesz=1G hugepages=8` — VM için 8GB büyük sayfa ayrımı
- `vendor-reset` modülü — GPU reset bug'larını düzeltir

### 🎮 Gaming Stack
- **Steam** (Proton entegre)
- **GameMode** — otomatik performans modu
- **MangoHud** — FPS + sistem metrikleri overlay
- **Gamescope** — kompozitör bypass, VRR desteği
- **ProtonUp-Qt** — Proton sürüm yöneticisi
- **Lutris / Heroic** — GOG & Epic Games desteği
- RADV Vulkan + `gpl,nggc` perftest optimizasyonları
- Hyprland `allow_tearing = true` + `vrr = 2`

### 🧠 VFIO / GPU Passthrough
- `system.activationScripts` ile gerçek hook dosyası yazımı (environment.etc değil)
- `prepare` → GPU'yu `amdgpu`'dan ayır, `vfio-pci`'ye bağla
- `release` → `vendor-reset`, `amdgpu` yeniden yükle, framebuffer sıfırla, `greetd` yeniden başlat
- Retry logic ile sağlam driver bind/unbind
- `vfio-pci` ID tablosu temizleme (`remove_id`)
- VM çalışırken headless monitor ile host masaüstü korunur
- Tüm adımlar `/var/log/libvirt/vfio.log`'a yazılır

### 🔊 Ses
- **PipeWire** — 48kHz, 128 quantum (low-latency mod)
- ALSA + PulseAudio + JACK uyumluluğu
- WirePlumber session manager

### 🖥️ Masaüstü
- **Hyprland** — tiling Wayland compositor
- **Waybar** — özelleştirilmiş status bar (GameMode göstergesi dahil)
- **Dunst** — bildirimler
- **Rofi** — uygulama başlatıcı
- **Hypridle / Hyprlock** — otomatik kilit ekranı
- **greetd + tuigreet** — minimal giriş ekranı (SDDM yok, Xserver yok)

### 🐚 Kabuk & Araçlar
- **Fish** kabuğu + **Starship** prompt
- **Zoxide** (akıllı cd), **fzf**, **eza** (ls yerine), **bat** (cat yerine)
- **ripgrep**, **fd**, **btop**, **nvtop (AMD)**

### 🎨 Tema
- **Catppuccin Mocha** — Hyprland, Waybar, Kitty, GTK 3/4, btop, fzf tutarlı tema
- **JetBrainsMono Nerd Font**
- **plus-cursor** imleç teması

### 📱 Entegrasyon
- **Waydroid** — Android container
- **KDE Connect** — telefon/cihaz entegrasyonu (firewall portları yapılandırılmış)
- **Flatpak** desteği
- **Looking Glass** — VM ekranını Linux'ta görmek için

---

## 🚨 Önemli Uyarılar

### VFIO — Tek GPU Riski

Bu yapılandırma GPU passthrough içerir. Kullanmadan önce:

- ✔ BIOS'ta **IOMMU etkinleştirilmiş** olmalı (AMD: SVM + IOMMU)
- ✔ Kernel parametrelerinde `amd_iommu=on iommu=pt` bulunmalı
- ✔ GPU PCI adresleri senin sistemine göre güncellenmiş olmalı

> **Tek GPU'nuz varsa:** VM başlatıldığında ekran çıkışı kaybolur. Recovery için TTY veya live USB gerekebilir. Çift GPU kurulumu **şiddetle** önerilir.

### GPU PCI Adreslerini Güncelle

`nixos/configuration.nix` içindeki hook script'te:

```bash
GPU_PCI="0000:0b:00.0"    # Bunu kendi GPU adresine göre değiştir
GPU_AUDIO="0000:0b:00.1"  # GPU'nun audio fonksiyonu
```

Kendi adresini bul:

```bash
lspci | grep -i vga
lspci | grep -i audio
```

### SSH Güvenliği

`nixos/configuration.nix`'te `PasswordAuthentication = false` aktif. Sisteme SSH ile bağlanmadan önce SSH key'ini ekle:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos
```

---

## 📁 Repo Yapısı

```
├── assets/                     # Ekran görüntüleri
├── etc/libvirt/hooks/          # QEMU hook script
├── gtk-3.0/                    # GTK3 Catppuccin Mocha teması
├── gtk-4.0/                    # GTK4 Catppuccin Mocha teması
├── hypr/
│   ├── hyprland.conf           # AMD/gaming odaklı Hyprland config
│   ├── hyprlock.conf           # Kilit ekranı
│   └── hypridle.conf           # Otomatik kilit/uyku
├── nix/
│   ├── nix.conf
│   └── registry.json
├── nixos/
│   ├── flake.nix               # CachyOS kernel + home-manager girişi
│   ├── flake.lock
│   ├── configuration.nix       # Ana sistem config + VFIO hook
│   ├── hardware-configuration.nix
│   └── home.nix                # Fish, Kitty, Starship, hypridle...
├── vm-xml/                     # Libvirt VM tanım dosyaları
│   └── win10.xml
└── waybar/
    ├── config                  # GameMode göstergesi dahil
    └── style.css               # Catppuccin Mocha
```

---

## 🚀 Kurulum

> ⚠️ NixOS + Flakes aktif olmalı  
> ⚠️ Dosyaları uygulamadan önce mutlaka incele — özellikle GPU PCI adreslerini güncelle

```bash
git clone https://github.com/kUmutUK/NixOS-Hyprland-Gaming-Config-AMD-Optimized-
cd NixOS-Hyprland-Gaming-Config-AMD-Optimized-

# NixOS config dosyalarını kopyala
sudo cp -r nixos/* /etc/nixos/

# Hyprland, Waybar ve diğer config'leri yerleştir
mkdir -p ~/.config
cp -r hypr ~/.config/hypr
cp -r waybar ~/.config/waybar
cp -r gtk-3.0 ~/.config/gtk-3.0
cp -r gtk-4.0 ~/.config/gtk-4.0

# Sistemi derle ve uygula
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## 🔧 Özelleştirme

| Bileşen        | Dosya                          |
|----------------|--------------------------------|
| Hyprland       | `hypr/hyprland.conf`           |
| Kilit ekranı   | `hypr/hyprlock.conf`           |
| Idle/Uyku      | `hypr/hypridle.conf`           |
| Waybar görünüm | `waybar/config` + `style.css`  |
| GTK Tema       | `gtk-3.0/` + `gtk-4.0/`       |
| Sistem servis  | `nixos/configuration.nix`      |
| Kullanıcı env  | `nixos/home.nix`               |
| VM tanımı      | `vm-xml/win10.xml`             |

---

## 🧪 Gaming Kullanımı

Önerilen Steam launch seçeneği:

```bash
mangohud gamemoderun gamescope -f -- %command%
```

CS2 için Hyprland'da özel window rule'lar tanımlı (tearing, noblur, noanim, immediate).

---

## 📱 Waydroid

```bash
# Android container başlat
waydroid session start

# Dosya aktar
cp dosya.zip ~/.local/share/waydroid/data/media/0/Download/
```

---

## 🔄 Sistem Güncelleme

```bash
# Flake girdilerini güncelle
nix flake update

# Sistemi yeniden derle
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Eski nesilleri temizle
nix-collect-garbage -d && sudo nix-collect-garbage -d
```

---

## 🧩 Gelecek Planları

- [ ] Modüler yapı (gaming / daily / server profilleri)
- [ ] VFIO toggle — VM açık/kapalıyken otomatik switch
- [ ] Installer script
- [ ] Daha kapsamlı Waybar widget'ları (GPU sıcaklığı, VFIO durumu)
- [ ] NVIDIA desteği (experimental)

---

## ❤️ Kredi

[github.com/kUmutUK](https://github.com/kUmutUK)

---

## 🪪 Lisans

MIT License

# 🚀 NixOS Hyprland Gaming + VFIO (AMD-Optimized)

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
  <img src="./assets/vm.png" width="49%" />
</p>

> ⚠️ **Advanced setup** — requires familiarity with Nix Flakes, Wayland and low-level Linux configuration.

A fully declarative NixOS setup combining a clean Hyprland desktop, AMD-focused gaming optimizations and **single-GPU VFIO passthrough** for Windows VMs.

---

## ✨ Key Features

### ⚙️ Kernel & Boot

* **CachyOS BORE kernel** via `xddxdd/nix-cachyos-kernel`
* AMD optimizations:

  * `amd_pstate=active`
  * `amd_iommu=on`
  * `iommu=pt`
  * `amdgpu.ppfeaturemask=0xfffd7fff`
* Low latency:

  * `rcupdate.rcu_expedited=1`
  * `nowatchdog`
  * `nmi_watchdog=0`
* AppArmor enabled

---

### 🎮 Gaming Stack

* Steam + Proton-GE
* GameMode (nice -10, I/O priority 0, GPU performance boost)
* MangoHud, Gamescope, Heroic, ProtonUp-Qt
* Vulkan (RADV):

  * `AMD_VULKAN_ICD=RADV`
  * `RADV_PERFTEST=gpl,nggc`
* Hyprland tweaks:

  * `allow_tearing=true`
  * `vrr=2`
  * per-game window rules

---

### 🔊 Audio

* PipeWire low-latency:

  * 48kHz
  * quantum 128
* ALSA, PulseAudio, JACK compatibility
* WirePlumber + rtkit

---

### 💾 Storage – LUKS2 + Btrfs

* Full disk encryption (LUKS2)
* Subvolumes:

  * `@`, `@home`, `@nix`, `@log`, `@snapshots`
* Mount options:

  * `compress=zstd:1`
  * `noatime`
  * `discard=async`
  * `space_cache=v2`
* Snapper (hourly snapshots + cleanup)
* Monthly scrub
* zram + disk swap

---

### 🖥️ Desktop

* Hyprland 0.54 (Wayland only)
* greetd + tuigreet (no X11)
* Waybar (custom modules)
* Dunst, Rofi
* Hypridle + Hyprlock
* mpvpaper (live wallpaper)

---

### 🧰 Shell & Tools

* Fish + Starship
* Zoxide, fzf
* eza, bat, ripgrep, fd
* btop, nvtop, fastfetch

---

### 🎨 Theme

* Catppuccin Mocha
* JetBrainsMono Nerd Font
* Capitaine Cursors
* Papirus Dark

---

### 🤖 AI Integration

* Ollama (ROCm) running continuously

---

### 🧪 VFIO / GPU Passthrough

* Fully declarative libvirt hooks
* `prepare`: stop greetd, unbind GPU → vfio-pci
* `release`: rebind GPU, restart greetd
* Single-GPU → host screen goes black (use Looking Glass / SPICE)

---

### 🔐 Security

* AppArmor
* Fail2ban (3 SSH failures → 48h ban)
* SSH password disabled, root login disabled
* Firewall enabled

---

### 🔗 Integration

* KDE Connect
* Waydroid
* Flatpak + GNOME Software
* Virt-Manager + Looking Glass

---

## 🧪 Tested Hardware

| Component | Model                 |
| --------- | --------------------- |
| CPU       | AMD Ryzen 5 5600      |
| GPU       | AMD Radeon RX 6700 XT |
| RAM       | 32 GB DDR4            |
| Storage   | NVMe SSD              |
| Arch      | x86_64-linux          |

---

## ⚡ Quick Start

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-
chmod +x install.sh
./install.sh
```

After installation:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## 📁 Repository Structure

```text
├── .github/workflows/
├── assets/
├── etc/libvirt/hooks/
├── nixos/
├── vm-xml/
├── wallpaper/
├── .gitignore
├── CHANGELOG.md
├── CONTRIBUTING.md
├── KURULUM.md
├── LICENSE
├── README.md
├── cs2.cfg
├── csgo.cfg
├── install.sh
└── shell.nix
```

---

## 📚 Documentation

### English

* `README.md` — overview & usage
* `CONTRIBUTING.md` — contribution guide
* `CHANGELOG.md` — version history

### Türkçe

* `KURULUM.md` — detaylı kurulum rehberi

---

## 🇹🇷 Turkish Installation Guide

Detaylı kurulum için:

```
KURULUM.md
```

İçerik:

* LUKS + Btrfs kurulum
* disk bölümlendirme
* hardware config
* VFIO setup
* troubleshooting

---

## 🎮 Usage

### Gaming

```bash
mangohud gamemoderun gamescope -f -- %command%
```

### VM

* `virt-manager` ile başlat
* GPU otomatik handle edilir

---

## 🛠 Development Shell

```bash
nix-shell
```

---

## 🔍 Validation

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

---

## 🤝 Contributing

```
CONTRIBUTING.md
```

---

## 📜 Changelog

```
CHANGELOG.md
```

---

## ⚠️ Notes

* `hardware-configuration.nix` makineye özeldir
* GPU PCI ID’lerini güncelle
* SSH sadece key ile çalışır

---

## 📄 License

MIT — see `LICENSE`

---

## 👑 Maintainer

**kUmutUK**

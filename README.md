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

## ✨ Features

* Hyprland 0.54 (Wayland-only desktop)
* CachyOS BORE kernel
* AMD gaming optimizations
* Steam + Proton-GE + MangoHud + Gamescope
* PipeWire low-latency audio
* LUKS2 + Btrfs + Snapper
* Fully declarative VFIO hooks
* Ollama ROCm support
* Home Manager integration
* Waydroid, Flatpak, KDE Connect, Looking Glass

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

## 📦 Repository Structure

```text
├── .github/workflows/      # CI checks
├── assets/                 # screenshots
├── etc/libvirt/hooks/      # VFIO hooks
├── nixos/                  # main NixOS configuration
├── vm-xml/                 # optional Windows VM XML files
├── wallpaper/              # wallpapers
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

* **README.md** — project overview, features and usage
* **CONTRIBUTING.md** — contribution guidelines
* **CHANGELOG.md** — version history

### Türkçe

* **KURULUM.md** — adım adım Türkçe kurulum rehberi

---

## 🇹🇷 Turkish Installation Guide

If you prefer a Turkish walkthrough, see:

```text
KURULUM.md
```

It includes:

* LUKS + Btrfs installation
* partition layout
* hardware configuration
* VFIO setup
* troubleshooting

---

## 🎮 Gaming

Launch games with:

```bash
mangohud gamemoderun gamescope -f -- %command%
```

---

## 🧪 VFIO

Single-GPU passthrough is fully declarative.

### Prepare hook

* stops greetd
* detaches GPU
* binds to vfio-pci

### Release hook

* reattaches GPU
* restarts greetd

> During VM runtime, the host display will go black.

---

## 🛠 Development Shell

A helper development shell is included:

```bash
nix-shell
```

Useful for:

* formatting
* testing
* quick Nix development

---

## 🔍 Validation

Before committing changes:

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

---

## 🤝 Contributing

Pull requests are welcome.

Please read:

```text
CONTRIBUTING.md
```

---

## 📜 Changelog

See:

```text
CHANGELOG.md
```

---

## ⚠️ Notes

* `hardware-configuration.nix` is **machine-specific** and not included
* update GPU PCI IDs for passthrough
* SSH password authentication is disabled by default

---

## 📄 License

MIT — see `LICENSE`

---

## 👑 Maintainer

**kUmutUK**

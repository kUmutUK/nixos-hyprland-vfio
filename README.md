# 🚀 NixOS Hyprland + VFIO

<p align="center">
  ⚡ Declarative • 🎮 Gaming • 🧪 VFIO • 🐧 NixOS
</p>

<p align="center">
  <img src="./assets/wall-.png" width="49%" />
  <img src="./assets/kitty-.png" width="49%" />
  Built for ultra-low latency Linux gaming and single-GPU virtualization.
</p>

<p align="center">
  Built for ultra-low latency Linux gaming and single-GPU virtualization.
</p>

AMD-optimized declarative gaming setup featuring:

- Hyprland Wayland desktop
- Low-latency gaming stack
- Hardware-agnostic Reflex / Anti-Lag 2
- Single-GPU VFIO passthrough
- Fully declarative NixOS configuration

> ⚠️ Advanced setup — intended for users familiar with NixOS, Wayland, virtualization and Linux system internals.

---

# ✨ Features

## ⚙️ Kernel & System

- CachyOS BORE kernel
- AMD optimized boot parameters:
  - `amd_pstate=active`
  - `amd_iommu=on`
  - `iommu=pt`
  - `amdgpu.ppfeaturemask=0xfffd7fff`
- Desktop responsiveness tuning:
  - `rcupdate.rcu_expedited=1`
  - `nowatchdog`
  - `nmi_watchdog=0`
- AppArmor enabled
- systemd initrd
- dbus-broker

### BORE Scheduler

The CachyOS BORE scheduler improves:

- desktop responsiveness
- frame pacing
- input latency
- task scheduling under gaming workloads

---

# 🎮 Gaming Stack

## Core

- Steam
- Proton-GE
- Heroic Games Launcher
- MangoHud
- Gamescope
- GameMode
- ProtonUp-Qt

## Low Latency

### low_latency_layer

Hardware-agnostic NVIDIA Reflex & AMD Anti-Lag 2 Vulkan layer.

Features:

- Global Reflex support
- NVIDIA spoofing for unsupported games
- Vulkan layer injection

Environment variables:

```bash
LOW_LATENCY_LAYER_REFLEX=1
LOW_LATENCY_LAYER_SPOOF_NVIDIA=1
```

### RADV Anti-Lag

```bash
RADV_ANTILAG=1
```

### Vulkan Tweaks

```bash
AMD_VULKAN_ICD=RADV
RADV_PERFTEST=gpl,nggc
```

### lsfg-vk

Vulkan-based frame generation support.

---

# 🖥️ Hyprland Desktop

- Hyprland 0.55.0+
- Wayland-only environment
- greetd + tuigreet
- Waybar
- Dunst
- Rofi
- Hypridle
- Hyprlock
- mpvpaper

## Gaming Tweaks

```ini
allow_tearing = true
vrr = 2
```

Per-game window rules included.

---

# 🔊 Audio

PipeWire low-latency configuration:

- 48kHz
- quantum = 128

Includes:

- ALSA
- PulseAudio compatibility
- JACK compatibility
- WirePlumber
- rtkit

---

# 💾 Storage

## LUKS2 + Btrfs

Features:

- Full disk encryption
- Btrfs subvolumes
- Snapper snapshots
- Monthly scrub
- zram + disk swap

### Subvolumes

- `@`
- `@home`
- `@nix`
- `@log`
- `@snapshots`

### Mount Options

```fstab
compress=zstd:1
noatime
discard=async
space_cache=v2
```

---

# 🤖 AI Integration

- Ollama with ROCm acceleration
- Local LLM support

---

# 🖥️ VFIO / GPU Passthrough

Single-GPU passthrough setup using declarative libvirt hooks.

## Workflow

### VM Start

- stop greetd
- unbind amdgpu
- bind vfio-pci
- launch Windows VM

### VM Stop

- rebind amdgpu
- restart greetd

## Notes

- Host display will go black during passthrough
- Looking Glass recommended
- IVSHMEM required for Looking Glass
- Some AMD GPUs may require vendor-reset

---

# 🔒 Security

- AppArmor
- Fail2ban
- Firewall enabled
- SSH password login disabled
- Root login disabled

---

# 🔗 Integration

- KDE Connect
- Waydroid
- Flatpak
- GNOME Software
- Virt-Manager
- Looking Glass

---

# 🧪 Tested Hardware

| Component | Model |
|---|---|
| CPU | AMD Ryzen 5 5600 |
| GPU | AMD Radeon RX 6700 XT |
| RAM | 32GB DDR4 |
| Storage | NVMe SSD |

---

# ⚡ Quick Start

## Clone

```bash
git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git
cd nixos-hyprland-vfio
```

## Run Installer

```bash
chmod +x install.sh
./install.sh
```

## Build System

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

# 📁 Repository Structure

```text
.
├── assets/
├── etc/libvirt/hooks/
├── nixos/
│   ├── configuration.nix
│   ├── hardware-configuration.nix
│   ├── home.nix
│   ├── flake.nix
│   ├── flake.lock
│   ├── hooks/
│   └── low_latency_layer.json.in
├── vm-xml/
├── wallpaper/
├── CHANGELOG.md
├── CONTRIBUTING.md
├── KURULUM.md
├── install.sh
├── shell.nix
└── README.md
```

---

# 📚 Documentation

## English

- README.md
- CONTRIBUTING.md
- CHANGELOG.md

## Türkçe

- KURULUM.md

---

# 🇹🇷 Turkish Installation Guide

Detailed installation instructions:

```text
KURULUM.md
```

Includes:

- disk partitioning
- LUKS2 setup
- Btrfs subvolumes
- VFIO configuration
- troubleshooting
- hardware configuration

---

# 🕹️ Usage

## Gaming

```bash
mangohud gamemoderun gamescope -f -- %command%
```

## Reflex / Anti-Lag 2

Already enabled globally.

For games requiring NVIDIA detection:

```bash
LOW_LATENCY_LAYER_SPOOF_NVIDIA=1 %command%
```

## VM

Launch via:

```bash
virt-manager
```

GPU passthrough is automatic.

---

# 🛠️ Development

## Legacy Shell

```bash
nix-shell
```

## Modern Flake Shell

```bash
nix develop
```

---

# ✅ Validation

```bash
nix flake check
sudo nixos-rebuild dry-activate --flake .#nixos
```

---

# ⚠️ Important Notes

- `hardware-configuration.nix` is machine-specific
- Update GPU PCI IDs for your hardware
- SSH authentication is key-only
- `low_latency_layer.json.in` is a template
- Single-GPU passthrough temporarily disables host graphics

---

# 📄 License

MIT License

---

# 👤 Maintainer

kUmutUK

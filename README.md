# 🚀 NixOS Hyprland Gaming Config (AMD Optimized • Flake)

## 🎯 Overview
![Screenshot](images/screenshot.png)
A **high-performance, low-latency NixOS configuration** designed for gaming and daily use.
Provides a **smooth, responsive and stable system** with minimal setup.

---

## 💻 System Specifications (Tested On)

This configuration has been tested on:

* CPU: AMD Ryzen 5 5600
* GPU: AMD Radeon RX 6000 Series
* RAM: 32GB DDR4
* Storage: NVMe SSD
* Architecture: x86_64-linux

---

## 🖥️ Environment

* OS: NixOS (Flake-based)
* Desktop: Hyprland (Wayland)
* Display Server: Wayland
* Shell: Bash
* Terminal: Kitty

---

## ⚡ Core Features

### 🖥️ Desktop

* Hyprland (tiling Wayland compositor)
* Waybar (custom status bar)
* Dunst (notifications)
* Rofi (launcher)

### 🎮 Gaming Stack

* Steam (Proton enabled)
* GameMode (auto performance boost)
* MangoHud (FPS + metrics overlay)
* Gamescope support
* ProtonUp-Qt

### 🔊 Audio

* PipeWire (low latency tuned)
* ALSA + Pulse compatibility

### 📱 Integration

* Waydroid (Android container)
* KDE Connect (device integration)

### ⚙️ System Tweaks

* AMD Vulkan (RADV) optimizations
* CPU governor tuning
* USB autosuspend disabled (no mouse/keyboard sleep)
* Optimized kernel parameters
* Low-latency audio config

---

## 📂 Repository Structure

```bash
NixOS-Hyprland-Gaming-Config-AMD-Optimized/
├── flake.nix
├── flake.lock
├── configuration.nix
├── hardware-configuration.nix
├── home.nix
├── hypr/
│   ├── hyprland.conf
│   └── hyprlock.conf
├── waybar/
│   ├── config
│   └── style.css
├── nix/
│   ├── nix.conf
│   └── registry.json
├── README.md
```

---

## ⚡ Installation (Flake)

```bash
git clone https://github.com/YOUR-USERNAME/NixOS-Hyprland-Gaming-Config-AMD-Optimized
cd NixOS-Hyprland-Gaming-Config-AMD-Optimized
sudo nixos-rebuild switch --flake .#nixos
```

---

## 🏠 Home Manager Integration

Automatically applies:

* Hyprland configuration
* Waybar configuration

---

## 🖥️ Hyprland Features

Includes:

* Custom keybindings
* Window rules
* Performance tweaks
* Screenshot support

### 📸 Screenshot

```bash
grim -g "$(slurp)" ~/Pictures/screenshot.png
```

Optional keybinds:

```bash
bind = , Print, exec, grim ~/Pictures/screenshot.png
bind = SHIFT, Print, exec, grim -g "$(slurp)" ~/Pictures/screenshot.png
```

---

## 📊 Waybar

Displays:

* CPU / GPU usage
* Memory
* Network
* Clock
* Workspaces

---

## 🎮 Gaming Usage

Recommended launch options:

```bash
mangohud gamemoderun %command%
```

---

## 📱 Waydroid

Start:

```bash
waydroid session start
```

File transfer:

```bash
cp file.zip ~/.local/share/waydroid/data/media/0/Download/
```

---

## 🔗 KDE Connect

* Enabled by default
* Firewall ports configured
* Works out-of-the-box

---

## 🧪 Tested Tools & Components

### 🖥️ System

* NixOS (Flake)
* Home Manager
* Hyprland

### 🎮 Gaming

* Steam
* GameMode
* MangoHud
* Gamescope

### 🌐 Apps

* Brave
* Firefox
* Discord
* Telegram

### 📊 Monitoring

* btop
* nvtop

### 📱 Integration

* Waydroid
* KDE Connect

### 🖼️ Desktop Tools

* Waybar
* Dunst
* Rofi
* Kitty

### 📸 Screenshot

* grim
* slurp
* wl-clipboard

---

## ⚙️ Nix Configuration (Advanced / Optional)

⚠️ WARNING:

The `nix/` directory contains system-level configs:

* nix.conf
* registry.json

These may:

* Override system behavior
* Break setups if misused

Apply manually:

```bash
sudo cp -r nix/* /etc/nix/
```

---

## 📌 Notes

* Optimized for performance (not battery)
* Designed for desktop usage
* Minimal post-install setup required

---

## 📸 Screenshots

*Add your desktop screenshots here*

---

## 🏷️ Topics

```
nixos hyprland wayland linux gaming dotfiles amd flakes
```

---

## 🔥 Goal

A **clean, minimal, fast, and powerful NixOS system**
ready for gaming and daily use out-of-the-box.

---

## 💬 Final

This is not just a config —
it is a **complete system setup**.

Clone → Build → Use.

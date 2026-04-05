NixOS Hyprland Gaming Config (AMD Optimized)

🎯 Purpose

This is a high-performance, low-latency NixOS configuration designed for gaming and daily use.
The goal is to provide a smooth, fast, and stable system with minimal input lag and no extra tweaking needed.

---

💻 Target Systems

Best suited for:

- 🟢 AMD CPUs (Ryzen recommended)
- 🟢 AMD GPUs (RADV / Mesa drivers)
- 🟢 Wayland + Hyprland setups
- 🟢 Desktop systems (SSD / NVMe)

Tested on:

- Ryzen 5 5600
- RX 6000 series GPU
- 32GB RAM

---

🚀 Features

- Hyprland (Wayland compositor)
- Waybar (custom UI)
- Low-latency PipeWire audio
- GameMode enabled
- MangoHud + Gamescope support
- Steam + Proton ready
- Waydroid (Android support)
- KDE Connect (device integration)
- USB autosuspend disabled (no mouse/keyboard sleep)
- Optimized kernel parameters

---

📂 Repository Structure

nixos-config/
├── configuration.nix
├── hardware-configuration.nix
├── hypr/
│   ├── hyprland.conf
│   └── hyprlock.conf
├── waybar/
│   ├── config
│   └── style.css
├── README.md

---

⚙️ Installation

sudo cp configuration.nix /etc/nixos/
sudo cp hardware-configuration.nix /etc/nixos/
sudo nixos-rebuild switch

---

🖥️ Hyprland Setup

mkdir -p ~/.config/hypr
cp -r hypr/* ~/.config/hypr/

---

📊 Waybar Setup

mkdir -p ~/.config/waybar
cp -r waybar/* ~/.config/waybar/

---

📌 Notes

- Focused on performance over battery life
- Ideal for desktop usage
- Minimal setup required after installation

---

🔥 Goal

A clean, fast, and responsive NixOS setup that performs great in both gaming and everyday tasks.

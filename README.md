NixOS Hyprland Gaming Config (AMD Optimized)

🎯 Purpose

This is a high-performance, low-latency NixOS configuration designed for both gaming and daily use.
It aims to provide a smooth, responsive, and stable experience out of the box without extra tweaking.

---

💻 Target Systems

Best suited for:

- 🟢 AMD CPUs (Ryzen recommended)
- 🟢 AMD GPUs (RADV / Mesa drivers)
- 🟢 Wayland + Hyprland environments
- 🟢 SSD / NVMe storage

Tested on:

- Ryzen 5 5600
- RX 6000 series GPU
- 32GB RAM

---

🚀 Features

- Hyprland (Wayland compositor)
- Low-latency PipeWire audio
- GameMode enabled
- MangoHud + Gamescope support
- Steam + Proton ready
- Waydroid (Android container support)
- KDE Connect (device integration)
- USB autosuspend disabled (no mouse/keyboard sleep)
- Optimized kernel parameters

---

⚙️ Installation

sudo cp configuration.nix /etc/nixos/
sudo cp hardware-configuration.nix /etc/nixos/
sudo nixos-rebuild switch

---

📌 Notes

- Focused on performance over battery life
- Ideal for desktop systems
- Minimal setup required after installation

---

🔥 Goal

A clean, fast, and stable NixOS setup that performs great in both gaming and everyday usage. 

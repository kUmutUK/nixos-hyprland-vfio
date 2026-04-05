NixOS Hyprland Gaming Config (Flake)

🎯 Purpose

This is a high-performance, low-latency NixOS configuration designed for gaming and daily use.
It provides a smooth, fast, and stable experience with minimal input lag and no extra tweaking required.

---

💻 Target Systems

Best suited for:

- 🟢 AMD CPUs (Ryzen recommended)
- 🟢 AMD GPUs (RADV / Mesa drivers)
- 🟢 Wayland + Hyprland environments
- 🟢 Desktop systems (SSD / NVMe)

---

🚀 Features

- Hyprland (Wayland compositor)
- Waybar (custom UI)
- Low-latency PipeWire audio
- GameMode enabled
- MangoHud + Gamescope support
- Steam + Proton ready
- Waydroid support
- KDE Connect
- USB autosuspend disabled
- Optimized kernel parameters

---

⚡ Installation (Flake)

git clone https://github.com/YOUR-USERNAME/nixos-config
cd nixos-config
sudo nixos-rebuild switch --flake .#nixos

---

📂 Repository Structure

nixos-config/
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

---

🖥️ Hyprland Setup

mkdir -p ~/.config/hypr
cp -r hypr/* ~/.config/hypr/

---

📊 Waybar Setup

mkdir -p ~/.config/waybar
cp -r waybar/* ~/.config/waybar/

---

⚙️ Nix Configuration (Advanced / Optional)

⚠️ WARNING:
These files are system-level configurations.
They may break your system if used incorrectly.

- Do NOT use unless you understand Nix configuration
- Not required for normal usage
- May override your system defaults

Apply manually:

sudo cp -r nix/* /etc/nix/

---

📌 Notes

- Focused on performance over battery life
- Designed for desktop systems
- Minimal setup required after install

---

🔥 Goal

A clean, fast, minimal and powerful NixOS setup for gaming and everyday use.

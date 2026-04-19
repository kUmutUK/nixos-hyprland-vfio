# 🧊 NixOS Hyprland Gaming + VFIO Config (AMD Optimized)

> ⚠️ **This is NOT a beginner-friendly setup**

A high-performance NixOS setup built for:

* 🎮 Gaming (AMD optimized)
* 🧠 GPU passthrough (VFIO)
* 🖥️ Hyprland (Wayland-first workflow)

Designed as a hybrid system:
→ Daily Linux usage
→ Windows VM with near-native performance

---

## 💡 Why This Setup?

Most Hyprland configs focus only on visuals.

This setup combines:

* A clean Wayland desktop (Hyprland)
* Gaming performance (AMD optimized)
* GPU passthrough (VFIO)

→ all in a single declarative NixOS system

---

## 🚨 Important Warnings

### ⚠️ Advanced Setup

This configuration is intended for:

* Intermediate / advanced NixOS users
* People familiar with:

  * Flakes
  * Wayland
  * System-level configuration

---

### ⚠️ VFIO / GPU Passthrough Risks

This repo includes **VFIO-related configuration**.

Before using:

* ✔ IOMMU **must be enabled** (BIOS + kernel)
* ✔ Proper GPU isolation required
* ✔ Recommended: **dual GPU setup**

#### ❗ If you have only ONE GPU:

You may:

* Lose display output
* Lock yourself out of the system
* Need recovery from TTY or live USB

---

### ⚠️ System Stability

* This is a **personal daily-driver config**
* Not tested on all hardware
* May require manual fixes

👉 Always review configs before applying

---

## 🎯 What This Repo Is

✔ Full **system configuration** (NOT just dotfiles)
✔ Declarative setup using **Nix Flakes**
✔ Hybrid workflow:

* Linux (Hyprland)
* Windows VM (GPU passthrough)

---

## ⚡ Key Features

### 🎮 Gaming Ready

* Mesa / RADV optimized
* Wayland-native workflow
* Low latency experience

### 🧠 VFIO Integration

* Libvirt hook system (auto-managed via Nix)
* QEMU hook support
* Logging:

  * `/var/log/libvirt/vfio-v3.log`


---

## ⚠️ Warning

This project may include VM XML (libvirt / QEMU / KVM) configurations and/or GPU passthrough settings.

Incorrect configuration may result in:
- VM failing to start
- GPU passthrough not working
- IOMMU / VFIO related errors
- In rare cases, issues with host graphics stability

Before installation, make sure to:
- Enable IOMMU in your BIOS/UEFI settings
- Verify kernel parameters are correctly configured
- Ensure correct PCI/GPU device selection

These configurations are intended for advanced users. Use at your own risk.

---

## 📁 Project Structure

> All configuration files are located under the `system/` directory.

```
system/
├── nixos/        # Core system config
├── hypr/         # Hyprland configs
├── waybar/       # Waybar setup
├── gtk-3.0/      # GTK3 theme
├── gtk-4.0/      # GTK4 theme
└── nix/          # Nix config
```

---

## 🖥️ Core Configuration

* `configuration.nix` → services + VFIO hooks
* `hardware-configuration.nix`
* `flake.nix`
* `home.nix`

---

## 🪟 Hyprland

```
system/hypr/
```

* `hyprland.conf`
* `hyprlock.conf`
* `hypridle.conf`

---

## 📊 Waybar

```
system/waybar/
```

* `config`
* `style.css`

---

## 🎨 GTK Theming

```
system/gtk-3.0/
system/gtk-4.0/
```

---

## ⚙️ Nix Configuration

```
system/nix/
```

* `nix.conf`
* `registry.json`

---

## 🚀 Installation

> ⚠️ Requires NixOS with flakes enabled
> ⚠️ Review configuration files before applying!

```bash
git clone https://github.com/kUmutUK/NixOS-Hyprland-Gaming-Config-AMD-Optimized-
cd NixOS-Hyprland-Gaming-Config-AMD-Optimized-
sudo cp -r system/nixos/* /etc/nixos/
sudo nixos-rebuild switch --flake .
```

---

## 🔧 Customization

| Component    | Path             |
| ------------ | ---------------- |
| Hyprland     | `system/hypr/`   |
| Waybar       | `system/waybar/` |
| GTK Theme    | `system/gtk-*`   |
| NixOS Config | `system/nixos/`  |

---

## 🧪 Tested On

* CPU: Ryzen 5 5600
* GPU: RX 6700 XT
* RAM: 32GB

---

## 📸 Preview

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
</p>

---

## 🧩 Future Plans

* [ ] NVIDIA support
* [ ] Safer VFIO toggle system
* [ ] Installer script
* [ ] Profiles (modular configs)

---

## ❤️ Credits

https://github.com/kUmutUK

---

## 🪪 License

MIT License

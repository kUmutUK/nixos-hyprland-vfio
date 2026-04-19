# 🧊 NixOS Hyprland Gaming + VFIO Config (AMD Optimized)

> ⚠️ **This is NOT a beginner-friendly setup.** Experience with Flakes, Wayland and system-level configuration is required.

A fully declarative NixOS configuration designed to run daily Linux usage and a Windows VM on the same machine with near-native performance.

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
  <img src="./assets/vm.png" width="49%" />
</p>

---

## 🎯 What Does This Setup Do?

Most Hyprland configs focus only on visuals. This configuration combines three things:

- 🖥️ Clean Wayland desktop (Hyprland + Catppuccin Mocha)
- 🎮 AMD-optimized gaming performance (RADV, GameMode, MangoHud, Gamescope)
- 🧠 GPU passthrough — hand your physical GPU to a Windows VM while Linux keeps running

→ All in a single declarative NixOS system

---

## 💻 Tested Hardware

| Component  | Model                   |
|------------|-------------------------|
| CPU        | AMD Ryzen 5 5600        |
| GPU        | AMD Radeon RX 6700 XT   |
| RAM        | 32GB DDR4               |
| Storage    | NVMe SSD                |
| Arch       | x86_64-linux            |

---

## ⚡ Key Features

### 🐧 Kernel
- **CachyOS BORE Kernel** — scheduler optimized for gaming and low latency
- `amd_pstate=guided` — AMD P-state frequency management
- `iommu=pt + amd_iommu=on` — IOMMU passthrough mode for VFIO
- `hugepagesz=1G hugepages=8` — 8GB huge page reservation for the VM
- `vendor-reset` module — fixes GPU reset bugs

### 🎮 Gaming Stack
- **Steam** (Proton integrated)
- **GameMode** — automatic performance boost
- **MangoHud** — FPS + system metrics overlay
- **Gamescope** — compositor bypass, VRR support
- **ProtonUp-Qt** — Proton version manager
- **Lutris / Heroic** — GOG & Epic Games support
- RADV Vulkan + `gpl,nggc` perftest optimizations
- Hyprland `allow_tearing = true` + `vrr = 2`

### 🧠 VFIO / GPU Passthrough
- Real hook file written via `system.activationScripts` (not environment.etc)
- `prepare` → unbind GPU from `amdgpu`, bind to `vfio-pci`
- `release` → `vendor-reset`, reload `amdgpu`, reset framebuffer, restart `greetd`
- Robust driver bind/unbind with retry logic
- `vfio-pci` ID table cleanup (`remove_id`)
- Headless monitor keeps host desktop alive while VM is running
- All steps logged to `/var/log/libvirt/vfio.log`

### 🔊 Audio
- **PipeWire** — 48kHz, 128 quantum (low-latency mode)
- ALSA + PulseAudio + JACK compatibility
- WirePlumber session manager

### 🖥️ Desktop
- **Hyprland** — tiling Wayland compositor
- **Waybar** — custom status bar (includes GameMode indicator)
- **Dunst** — notifications
- **Rofi** — application launcher
- **Hypridle / Hyprlock** — automatic lock screen
- **greetd + tuigreet** — minimal login manager (no SDDM, no Xserver)

### 🐚 Shell & Tools
- **Fish** shell + **Starship** prompt
- **Zoxide** (smart cd), **fzf**, **eza** (ls replacement), **bat** (cat replacement)
- **ripgrep**, **fd**, **btop**, **nvtop (AMD)**

### 🎨 Theme
- **Catppuccin Mocha** — consistent across Hyprland, Waybar, Kitty, GTK 3/4, btop, fzf
- **JetBrainsMono Nerd Font**
- **plus-cursor** cursor theme

### 📱 Integration
- **Waydroid** — Android container
- **KDE Connect** — phone/device integration (firewall ports configured)
- **Flatpak** support
- **Looking Glass** — view VM display from Linux

---

## 🚨 Important Warnings

### VFIO — Single GPU Risk

This configuration includes GPU passthrough. Before using:

- ✔ **IOMMU must be enabled** in BIOS (AMD: SVM + IOMMU)
- ✔ Kernel parameters must include `amd_iommu=on iommu=pt`
- ✔ GPU PCI addresses must be updated for your system

> **If you only have ONE GPU:** Display output will be lost when the VM starts. Recovery via TTY or live USB may be required. A dual GPU setup is **strongly** recommended.

### Update GPU PCI Addresses

Inside the hook script in `nixos/configuration.nix`:

```bash
GPU_PCI="0000:0b:00.0"    # Replace with your GPU PCI address
GPU_AUDIO="0000:0b:00.1"  # GPU audio function
```

Find your addresses:

```bash
lspci | grep -i vga
lspci | grep -i audio
```

### SSH Security

`PasswordAuthentication = false` is active in `nixos/configuration.nix`. Add your SSH key before connecting:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos
```

---

## 📁 Repository Structure

```
├── assets/                     # Screenshots
├── etc/libvirt/hooks/          # QEMU hook script
├── gtk-3.0/                    # GTK3 Catppuccin Mocha theme
├── gtk-4.0/                    # GTK4 Catppuccin Mocha theme
├── hypr/
│   ├── hyprland.conf           # AMD/gaming-focused Hyprland config
│   ├── hyprlock.conf           # Lock screen
│   └── hypridle.conf           # Auto lock/sleep
├── nix/
│   ├── nix.conf
│   └── registry.json
├── nixos/
│   ├── flake.nix               # CachyOS kernel + home-manager entry
│   ├── flake.lock
│   ├── configuration.nix       # Core system config + VFIO hook
│   ├── hardware-configuration.nix
│   └── home.nix                # Fish, Kitty, Starship, hypridle...
├── vm-xml/                     # Libvirt VM definition files
│   └── win10.xml
├── waybar/
│   ├── config                  # Includes GameMode indicator
│   └── style.css               # Catppuccin Mocha
└── install.sh                  # ⚠️ Experimental installer (see below)
```

---

## 🚀 Installation

### ✅ Recommended — Manual Copy

> ⚠️ NixOS with Flakes enabled is required  
> ⚠️ Review all config files before applying — especially update the GPU PCI addresses

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git 
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-

# Copy NixOS config files — do NOT copy hardware-configuration.nix!
sudo cp nixos/configuration.nix /etc/nixos/
sudo cp nixos/home.nix /etc/nixos/
sudo cp nixos/flake.nix /etc/nixos/
sudo cp nixos/flake.lock /etc/nixos/

# Place Hyprland, Waybar and other configs
mkdir -p ~/.config
cp -r hypr ~/.config/hypr
cp -r waybar ~/.config/waybar
cp -r gtk-3.0 ~/.config/gtk-3.0
cp -r gtk-4.0 ~/.config/gtk-4.0

# Build and apply
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

### ⚠️ Experimental — Installer Script

> ❗ **Manual copying is strongly recommended over this method.**  
> The installer script does NOT automatically apply GPU PCI addresses.  
> It will back up your existing configs and copy files — nothing more.  
> Always review `nixos/configuration.nix` and update GPU addresses before rebuilding.

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-
chmod +x install.sh
./install.sh
```

**What the script does:**
- Detects GPU PCI addresses and **shows** them (does NOT apply automatically)
- Backs up existing `~/.config/hypr`, `waybar`, `gtk-*` and `/etc/nixos/*.nix`
- Copies config files to the correct locations
- Reminds you of all required manual steps before rebuilding

**What the script does NOT do:**
- Does NOT run `nixos-rebuild`
- Does NOT modify GPU PCI addresses
- Does NOT copy `hardware-configuration.nix`

---

## 🔧 Customization

| Component      | File                           |
|----------------|--------------------------------|
| Hyprland       | `hypr/hyprland.conf`           |
| Lock screen    | `hypr/hyprlock.conf`           |
| Idle/Sleep     | `hypr/hypridle.conf`           |
| Waybar layout  | `waybar/config` + `style.css`  |
| GTK Theme      | `gtk-3.0/` + `gtk-4.0/`       |
| System config  | `nixos/configuration.nix`      |
| User env       | `nixos/home.nix`               |
| VM definition  | `vm-xml/win10.xml`             |

---

## 🧪 Gaming Usage

Recommended Steam launch option:

```bash
mangohud gamemoderun gamescope -f -- %command%
```

Custom Hyprland window rules are defined for CS2 (tearing, noblur, noanim, immediate).

---

## 📱 Waydroid

```bash
# Start Android container
waydroid session start

# Transfer files
cp file.zip ~/.local/share/waydroid/data/media/0/Download/
```

---

## 🔄 System Update

```bash
# Update flake inputs
nix flake update

# Rebuild system
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# Clean old generations
nix-collect-garbage -d && sudo nix-collect-garbage -d
```

---

## 🧩 Future Plans

- [ ] Modular structure (gaming / daily / server profiles)
- [ ] VFIO toggle — automatic switch when VM starts/stops
- [ ] Improved installer script
- [ ] Extended Waybar widgets (GPU temp, VFIO status)
- [ ] NVIDIA support (experimental)

---

## ❤️ Credits

[github.com/kUmutUK](https://github.com/kUmutUK)

---

## 🪪 License

MIT License

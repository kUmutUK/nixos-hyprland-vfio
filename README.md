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
- 🤖 Local AI inference via Ollama with ROCm GPU acceleration

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
- `amd_pstate=active` — AMD P-state frequency management (active EPP mode)
- `iommu=pt + amd_iommu=on` — IOMMU passthrough mode for VFIO
- Dynamic hugepage management via VFIO hook script (2MB pages, 4GB reserved on VM start, freed on release)
- `vendor-reset` module — fixes GPU reset bugs on AMD cards
- `rcupdate.rcu_expedited=1` — reduced scheduling latency (pairs with BORE)

### 🎮 Gaming Stack
- **Steam** (Proton integrated, Proton-GE via `proton-ge-bin`)
- **GameMode** — full configuration: renice=-10, ioprio=0, GPU performance level forced to `high`
- **MangoHud** — FPS + system metrics overlay
- **Gamescope** — compositor bypass, VRR support; Steam Big Picture session enabled
- **ProtonUp-Qt** — Proton version manager
- **Lutris / Heroic** — GOG & Epic Games support
- RADV Vulkan (`AMD_VULKAN_ICD=RADV`) + `gpl,nggc` perftest optimizations
- Hyprland `allow_tearing = true` + `vrr = 2` + `vfr = true`
- Custom CS2 window rule: tearing, no blur, no shadow, no animation, immediate rendering

### 🧠 VFIO / GPU Passthrough
- Hook file deployed via `environment.etc` (NixOS-idiomatic, no activation scripts)
- `prepare` → stop Ollama, unbind GPU from `amdgpu`, bind to `vfio-pci`
- `release` → `vendor-reset`, reload `amdgpu`, reset framebuffer, restart `greetd`, restart Ollama
- `stopped` fallback — attempts `amdgpu` rebind on unexpected VM crash/force-off
- Robust driver bind/unbind with 5-retry logic
- `vfio-pci` ID table cleanup (`remove_id`) on release
- Headless monitor (`HEADLESS-1`) keeps host desktop alive while VM is running
- All steps logged to `/var/log/libvirt/vfio.log` (log rotated on boot via tmpfiles)
- Ollama service stopped before GPU handoff and restarted after GPU returns

### 🔊 Audio
- **PipeWire** — 48kHz, 128 quantum fixed (min=max for consistent low latency)
- ALSA + PulseAudio + JACK compatibility
- WirePlumber session manager
- rtkit enabled for real-time priority

### 💾 Storage — LUKS2 + Btrfs
- Full disk encryption with LUKS2 (`aes-xts-plain64`, 512-bit key, argon2id KDF)
- `allowDiscards` + `bypassWorkqueues` for NVMe performance through LUKS
- Btrfs subvolume layout: `@` `/`, `@home`, `@nix`, `@log`, `@snapshots`
- `compress=zstd:1`, `noatime`, `discard=async`, `space_cache=v2` on all subvolumes
- `/nix` subvolume uses `nodatacow` — avoids CoW write amplification on Nix store hardlinks
- VM disk images directory (`/var/lib/libvirt/images`) also has `nodatacow` via systemd tmpfiles + `chattr +C`
- **Snapper** automatic snapshots: hourly (10 kept), daily (7), weekly (4), monthly (6) for both `/` and `/home`
- **Btrfs scrub** — monthly on `/`
- **zramSwap** with zstd compression (~8GB on 16GB RAM); physical swap partition used only for hibernation

### 🖥️ Desktop
- **Hyprland** — tiling Wayland compositor
- **Waybar** — custom status bar (GameMode indicator, Japanese workspace icons, CPU/RAM/temp)
- **Dunst** — notifications
- **Rofi** — application launcher
- **Hypridle / Hyprlock** — automatic lock and sleep (managed as Home Manager systemd user service)
- **greetd + tuigreet** — minimal login manager (no SDDM, no Xserver)
- **swww** — wallpaper daemon managed as systemd user service (Restart=on-failure)
- Wallpaper randomized every 5 minutes via systemd user timer

### 🐚 Shell & Tools
- **Fish** shell + **Starship** prompt
- **Zoxide** (smart cd), **fzf** with Catppuccin Mocha colors, **eza** (ls replacement), **bat** (cat replacement)
- **ripgrep**, **fd**, **btop**, **nvtop (AMD)**
- Useful aliases: `nrs` (nixos-rebuild switch), `nup` (flake update), `nclean` (garbage collect), `snap-root`, `snap-home`, `btrfs-df`

### 🎨 Theme
- **Catppuccin Mocha** — consistent across Hyprland, Waybar, Kitty, GTK 3/4, btop, fzf
- **JetBrainsMono Nerd Font** (size 11, in Kitty)
- **plus-cursor** cursor theme (size 16)

### 🤖 AI Integration
- **Ollama** with ROCm acceleration — RX 6700 XT (gfx1031) natively supported via `ollama-rocm`
- Automatically stopped before GPU passthrough and restarted after GPU returns to host

### 📱 Integration
- **Waydroid** — Android container
- **KDE Connect** — phone/device integration (TCP/UDP 1714–1764 firewall ports configured)
- **Flatpak** support
- **Looking Glass** — view VM display from Linux without a second monitor

---

## 🚨 Important Warnings

### VFIO — Single GPU Risk

This configuration includes GPU passthrough. Before using:

- ✔ **IOMMU must be enabled** in BIOS (AMD: SVM + IOMMU)
- ✔ Kernel parameters must include `amd_iommu=on iommu=pt`
- ✔ GPU PCI addresses must be updated for your system

> **If you only have ONE GPU:** Display output will be lost when the VM starts. A headless virtual output keeps the Hyprland session alive, but you will need Looking Glass or SPICE to interact with the VM. A dual GPU setup is **strongly** recommended.

### Update GPU PCI Addresses

Inside the hook script in `nixos/configuration.nix`:

```bash
GPU_PCI="0000:0b:00.0"    # Replace with your GPU PCI address
GPU_AUDIO="0000:0b:00.1"  # GPU audio function
```

Also update the vfio-pci device IDs:

```bash
echo "1002 73df" > ...    # GPU device ID (currently RX 6700 XT)
echo "1002 ab28" > ...    # GPU audio device ID
```

Find your addresses and IDs:

```bash
lspci -nn | grep -i vga
lspci -nn | grep -i audio
```

### SSH Security

`PasswordAuthentication = false` is active in `nixos/configuration.nix`. Add your SSH key before connecting:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos
```

### Initial Password

The config uses `initialPassword = "nixos"` for first boot only. Generate and set a proper hashed password during installation:

```bash
nix-shell -p mkpasswd --run "mkpasswd -m sha-512" > /mnt/etc/nixos/passwd-umpug
chmod 600 /mnt/etc/nixos/passwd-umpug
```

Then set `hashedPasswordFile = "/etc/nixos/passwd-umpug"` in `configuration.nix` and remove `initialPassword`.

---

## 📁 Repository Structure

```
├── assets/                         # Screenshots
├── system/
│   ├── gtk-3.0/                    # GTK3 Catppuccin Mocha theme
│   │   ├── colors.css
│   │   └── gtk.css
│   ├── gtk-4.0/                    # GTK4 Catppuccin Mocha theme
│   │   ├── colors.css
│   │   └── gtk.css
│   ├── hypr/
│   │   ├── hyprland.conf           # AMD/gaming-focused Hyprland config
│   │   └── hyprlock.conf           # Lock screen
│   ├── nixos/
│   │   ├── flake.nix               # CachyOS kernel + home-manager entry
│   │   ├── configuration.nix       # Core system config + VFIO hook script
│   │   ├── hardware-configuration.nix  # LUKS2 + Btrfs mount points
│   │   └── home.nix                # Fish, Kitty, Starship, hypridle, swww...
│   └── waybar/
│       ├── config                  # Includes GameMode indicator
│       └── style.css               # Catppuccin Mocha
└── KURULUM.md                      # Turkish step-by-step installation guide
```

> **Note:** `hypridle` is configured as a Home Manager systemd user service inside `home.nix`, not as a standalone file.

---

## 🚀 Installation

> ⚠️ NixOS with Flakes enabled is required  
> ⚠️ Review all config files before applying — especially update GPU PCI addresses and device IDs

See **KURULUM.md** for the full step-by-step installation guide including disk partitioning, LUKS2 setup, Btrfs subvolumes, UUID placement and password hashing.

**Quick path (existing NixOS install):**

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-

# Copy NixOS config files — do NOT copy hardware-configuration.nix!
sudo cp system/nixos/configuration.nix /etc/nixos/
sudo cp system/nixos/home.nix          /etc/nixos/
sudo cp system/nixos/flake.nix         /etc/nixos/

# Update GPU PCI addresses and device IDs in configuration.nix before rebuilding!
nano /etc/nixos/configuration.nix

# Build and apply
sudo nixos-rebuild switch --flake /etc/nixos#nixos

# After first boot — place user configs
cp -r system/hypr    ~/.config/hypr
cp -r system/waybar  ~/.config/waybar
cp -r system/gtk-3.0 ~/.config/gtk-3.0
cp -r system/gtk-4.0 ~/.config/gtk-4.0
```

---

## 🔧 Customization

| Component         | File                                |
|-------------------|-------------------------------------|
| Hyprland          | `system/hypr/hyprland.conf`         |
| Lock screen       | `system/hypr/hyprlock.conf`         |
| Idle/Sleep        | `system/nixos/home.nix` (hypridle)  |
| Waybar layout     | `system/waybar/config`              |
| Waybar style      | `system/waybar/style.css`           |
| GTK Theme         | `system/gtk-3.0/` + `gtk-4.0/`     |
| System config     | `system/nixos/configuration.nix`    |
| User environment  | `system/nixos/home.nix`             |

---

## 🧪 Gaming Usage

Recommended Steam launch option:

```bash
mangohud gamemoderun gamescope -f -- %command%
```

Custom Hyprland window rules are defined for CS2 (`tearing`, `no_blur`, `no_shadow`, `no_anim`, `immediate`, `fullscreen`).

Check GameMode status from the terminal:

```bash
gm-status   # alias for: gamemoded -s
```

---

## 🤖 Ollama / Local AI

Ollama runs with ROCm GPU acceleration automatically. The VFIO hook gracefully stops Ollama before handing the GPU to the VM and restarts it after the VM shuts down.

```bash
# Check Ollama status
systemctl status ollama

# Pull and run a model
ollama pull llama3
ollama run llama3
```

---

## 💾 Snapshots

Snapper manages automatic Btrfs snapshots for `/` and `/home`.

```bash
snap-root          # alias: sudo snapper -c root list
snap-home          # alias: sudo snapper -c home list
snap-diff          # alias: sudo snapper -c root diff
btrfs-df           # alias: sudo btrfs filesystem df /
btrfs-cmp          # alias: sudo compsize -x /
```

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
nup      # alias: nix flake update
nrs      # alias: sudo nixos-rebuild switch --flake /etc/nixos#nixos
ntest    # alias: sudo nixos-rebuild dry-activate --flake /etc/nixos#nixos
nclean   # alias: nix-collect-garbage -d && sudo nix-collect-garbage -d
```

---

## 🧩 Future Plans

- [ ] Modular structure (gaming / daily / server profiles)
- [ ] CPU pinning / isolation for VFIO VM (isolcpus + taskset)
- [ ] Secure Boot support via lanzaboote + TPM2
- [ ] Extended Waybar widgets (GPU temp, VFIO status indicator)
- [ ] NVIDIA support (experimental)

---

## ❤️ Credits

[github.com/kUmutUK](https://github.com/kUmutUK)

---

## 🪪 License

MIT License

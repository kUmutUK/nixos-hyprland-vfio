# NixOS Hyprland Gaming + VFIO (AMD Optimized)

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
  <img src="./assets/vm.png" width="49%" />
</p>

⚠️ Advanced setup – requires familiarity with Nix Flakes, Wayland and low-level system configuration.

A fully declarative NixOS configuration that merges a clean Wayland desktop, AMD-tuned gaming performance and single-GPU passthrough for a Windows VM into one reproducible system.

---

## Tested Hardware

| Component | Model |
|----------|------|
| CPU | AMD Ryzen 5 5600 |
| GPU | AMD Radeon RX 6700 XT |
| RAM | 32 GB DDR4 |
| Storage | NVMe SSD |
| Arch | x86_64-linux |

---

## Key Features

### Kernel & Boot
- CachyOS BORE kernel via `xddxdd/nix-cachyos-kernel` overlay
- AMD optimisations:
  - `amd_pstate=active`
  - `amd_iommu=on`
  - `iommu=pt`
  - `amdgpu.ppfeaturemask=0xffffffff`
- Low latency:
  - `rcupdate.rcu_expedited=1`
  - `nowatchdog`
  - `nmi_watchdog=0`
- AppArmor enabled

---

### Gaming Stack
- Steam with Proton-GE (`proton-ge-bin`)
- GameMode:
  - `renice=-10`
  - `ioprio=0`
  - Forces GPU high performance
  - Custom hooks pause/restart video wallpaper
- MangoHud, Gamescope, ProtonUp-Qt, Heroic
- RADV Vulkan:
  - `AMD_VULKAN_ICD=RADV`
  - `RADV_PERFTEST=gpl,nggc`
- Hyprland optimisations:
  - `allow_tearing=true`
  - `vrr=2`
  - Special rules for CS2 & gamescope

---

### Audio
- PipeWire low-latency:
  - 48 kHz
  - quantum 128 (min=max=128, max=256)
- ALSA + PulseAudio + JACK compatibility
- WirePlumber + rtkit

---

### Storage – LUKS2 + Btrfs
- Full disk encryption (LUKS2)
  - `aes-xts-plain64`
  - `argon2id`
- Subvolumes:
  - `@`, `@home`, `@nix`, `@log`, `@snapshots`
- Mount options:
  - `compress=zstd:1`
  - `noatime`
  - `discard=async`
  - `space_cache=v2`
  - `/nix` → `nodatacow`
- Snapper snapshots:
  - hourly (10)
  - daily (7)
  - weekly (4)
  - monthly (6)
- Monthly scrub
- zramSwap + disk swap (hibernate)

---

### Desktop
- Hyprland (Wayland)
- Waybar (GameMode indicator, system stats, MPRIS)
- Dunst (notifications)
- Rofi (launcher)
- Hypridle / Hyprlock
- Greetd + Tuigreet (no X11)
- mpvpaper (video wallpaper)

---

### Shell & Tools
- Fish + Starship
- Zoxide, fzf, eza, bat
- ripgrep, fd, btop, nvtop, fastfetch

Aliases:
```bash
nrs
nup
nclean
snap-root
snap-home
btrfs-df
```

---

### Theme
- Catppuccin Mocha
- JetBrainsMono Nerd Font (size 11)
- Capitaine Cursors (16)
- Papirus Dark icons

---

### AI Integration
- Ollama (ROCm)
- RX 6700 XT supported (gfx1031)
- Runs continuously (not stopped during VFIO)

---

### VFIO / GPU Passthrough

- Declarative libvirt hook:
  - `/etc/libvirt/hooks/qemu`

#### prepare:
- Stops greetd
- Unbinds GPU from amdgpu
- Binds to vfio-pci
- Logs → `/var/log/libvirt/vfio.log`

#### release:
- Rebinds GPU
- Restarts greetd

Notes:
- Single GPU → host display goes off
- Use Looking Glass or SPICE

---

### Security
- AppArmor
- Fail2ban (3 attempts → 48h ban)
- SSH:
  - password disabled
  - root login disabled
- Firewall enabled

---

### Integration
- KDE Connect
- Waydroid
- Flatpak + GNOME Software
- Virt-Manager + Looking Glass

---

## Repository Structure

```
├── assets/
├── install.sh
├── cs2.cfg
├── csgo.cfg
├── etc/libvirt/hooks/qemu
├── nixos/
│   ├── flake.nix
│   ├── flake.lock
│   ├── configuration.nix
│   └── home.nix
├── vm-xml/win10.xml
├── wallpaper/
└── KURULUM.md
```

⚠️ `hardware-configuration.nix` dahil değil.

---

## Installation

### 1. Clone repo
```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-
```

### 2. Generate hardware config
```bash
nixos-generate-config
```

→ `nixos/hardware-configuration.nix` içine koy

---

### 3. Edit required values

#### configuration.nix
- GPU PCI IDs
- username
- password

#### home.nix
- username
- git config
- wallpaper path

---

### 4. Copy to system
```bash
sudo cp -r nixos/* /etc/nixos/
```

---

### 5. Apply config
```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## Post Install

```bash
waydroid init -f
ollama pull llama3
```

---

## Usage

### Gaming
```bash
mangohud gamemoderun gamescope -f -- %command%
```

---

### VFIO VM
- GPU auto detach/attach
- Desktop stops during VM
- Logs → `/var/log/libvirt/vfio.log`

---

### Snapper
```bash
snap-root
snap-home
btrfs-df
```

---

### Maintenance
```bash
nrs
nup
nclean
ntest
```

---

## Important Notes

### ⚠️ Single GPU
VM çalışırken ekran gider.

### GPU IDs
```bash
lspci -nn | grep -i vga
lspci -nn | grep -i audio
```

---

### SSH
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub localhost@nixos
```

---

### Default Password
```
nixos
```
→ değiştir!

---

## Future Plans
- Modular flake
- CPU pinning
- Secure Boot
- Waybar extensions
- NVIDIA support

---

## License
MIT

Maintainer: kUmutUK

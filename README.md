# NixOS Hyprland Gaming + VFIO (AMD-Optimized)

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>
<p align="center">
  <img src="./assets/app.png" width="49%" />
  <img src="./assets/vm.png" width="49%" />
</p>

> ⚠️ **Advanced setup** – requires familiarity with Nix Flakes, Wayland and low‑level system configuration.

A fully declarative NixOS configuration that merges a clean Wayland desktop, AMD‑tuned gaming performance and **single‑GPU passthrough** for a Windows VM into one reproducible system.

---

## Tested Hardware

| Component | Model |
|-----------|-------|
| CPU       | AMD Ryzen 5 5600 |
| GPU       | AMD Radeon RX 6700 XT |
| RAM       | 32 GB DDR4 |
| Storage   | NVMe SSD |
| Arch      | x86_64-linux |

---

## Key Features

### Kernel & Boot
- **CachyOS BORE kernel** via `xddxdd/nix-cachyos-kernel` overlay
- AMD optimisations: `amd_pstate=active`, `amd_iommu=on`, `iommu=pt`, `amdgpu.ppfeaturemask=0xfffd7fff`
- Low latency: `rcupdate.rcu_expedited=1`, `nowatchdog`, `nmi_watchdog=0`
- AppArmor enabled

### Gaming Stack
- Steam with Proton‑GE
- GameMode (nice -10, I/O priority 0, GPU high performance, custom hooks for mpvpaper)
- MangoHud, Gamescope, ProtonUp‑Qt, Heroic
- RADV Vulkan: `AMD_VULKAN_ICD=RADV`, `RADV_PERFTEST=gpl,nggc`
- Hyprland tweaks: `allow_tearing=true`, `vrr=2`, per‑game window rules

### Audio
- PipeWire low‑latency: 48 kHz, quantum 128 (min=max=128, max=256)
- ALSA, PulseAudio, JACK compatibility via PipeWire
- WirePlumber + rtkit

### Storage – LUKS2 + Btrfs
- Full disk encryption (LUKS2)
- Btrfs subvolumes: `@`, `@home`, `@nix`, `@log`, `@snapshots`
- Mount options: `compress=zstd:1`, `noatime`, `discard=async`, `space_cache=v2` (`/nix` nodatacow)
- Snapper hourly snapshots with automatic cleanup
- Monthly scrub, zramSwap (zstd) + disk swap

### Desktop
- Hyprland 0.54 (Wayland) + greetd/Tuigreet (no X11)
- Waybar with custom modules (CPU, RAM, temp, GameMode, MPRIS, network)
- Dunst, Rofi, Hypridle/Hyprlock, mpvpaper (video wallpaper)

### Shell & Tools
- Fish + Starship, Zoxide, fzf, eza, bat, ripgrep, fd
- btop, nvtop (AMD), fastfetch, convenient aliases

### Theme
- Catppuccin Mocha GTK, JetBrainsMono Nerd Font, Capitaine Cursors, Papirus Dark icons

### AI Integration
- Ollama on ROCm (`ollama-rocm`), runs continuously

### VFIO / GPU Passthrough
- Declarative libvirt hook managed entirely by Nix
- `prepare`: stops greetd, unbinds GPU → vfio-pci, logs to `/var/log/libvirt/vfio.log`
- `release`: rebinds GPU, restarts greetd
- Single‑GPU: host display goes black – use Looking Glass or SPICE

### Security
- AppArmor, Fail2ban (3 SSH failures → 48h ban)
- SSH password auth disabled, root login forbidden, firewall enabled

### Integration
- KDE Connect, Waydroid, Flatpak + GNOME Software, Virt‑Manager + Looking Glass

---

## Repository Structure

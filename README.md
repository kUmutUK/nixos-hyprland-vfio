# 🚀 NixOS Hyprland Gaming + VFIO (AMD-Optimized)

<p align="center">
  <img src="./assets/desktop.png" width="49%" />
  <img src="./assets/terminal.png" width="49%" />
</p>

<p align="center">
  <img src="./assets/app.png" width="49%" />
  <img src="./assets/vm.png" width="49%" />
</p>

> ⚠️ **Advanced setup** – requires familiarity with Nix Flakes, Wayland and low-level system configuration.

A fully declarative NixOS configuration that merges a clean Wayland desktop, AMD-tuned gaming performance and **single-GPU passthrough** for a Windows VM into one reproducible system.

---

## 🧪 Tested Hardware

| Component | Model                 |
| --------- | --------------------- |
| CPU       | AMD Ryzen 5 5600      |
| GPU       | AMD Radeon RX 6700 XT |
| RAM       | 32 GB DDR4            |
| Storage   | NVMe SSD              |
| Arch      | x86_64-linux          |

---

## ✨ Key Features

### ⚙️ Kernel & Boot

* **CachyOS BORE kernel** via `xddxdd/nix-cachyos-kernel`
* AMD optimizations:

  * `amd_pstate=active`
  * `amd_iommu=on`
  * `iommu=pt`
  * `amdgpu.ppfeaturemask=0xfffd7fff`
* Low latency:

  * `rcupdate.rcu_expedited=1`
  * `nowatchdog`
  * `nmi_watchdog=0`
* AppArmor enabled

---

### 🎮 Gaming Stack

* Steam + Proton-GE
* GameMode (nice -10, I/O priority 0, GPU performance boost)
* MangoHud, Gamescope, Heroic, ProtonUp-Qt
* Vulkan (RADV):

  * `AMD_VULKAN_ICD=RADV`
  * `RADV_PERFTEST=gpl,nggc`
* Hyprland tweaks:

  * `allow_tearing=true`
  * `vrr=2`
  * per-game window rules

---

### 🔊 Audio

* PipeWire low-latency:

  * 48kHz
  * quantum 128
* Full compatibility:

  * ALSA
  * PulseAudio
  * JACK
* WirePlumber + rtkit

---

### 💾 Storage – LUKS2 + Btrfs

* Full disk encryption (LUKS2)
* Subvolumes:

  * `@`, `@home`, `@nix`, `@log`, `@snapshots`
* Mount options:

  * `compress=zstd:1`
  * `noatime`
  * `discard=async`
  * `space_cache=v2`
* Snapper:

  * hourly snapshots
  * auto cleanup
* Monthly scrub
* zram + disk swap

---

### 🖥️ Desktop

* Hyprland 0.54 (Wayland only)
* greetd + tuigreet (no X11)
* Waybar (custom modules)
* Dunst, Rofi
* Hypridle + Hyprlock
* mpvpaper (live wallpaper)

---

### 🧰 Shell & Tools

* Fish + Starship
* Zoxide, fzf
* eza, bat, ripgrep, fd
* btop, nvtop, fastfetch

---

### 🎨 Theme

* Catppuccin Mocha
* JetBrainsMono Nerd Font
* Capitaine Cursors
* Papirus Dark

---

### 🤖 AI Integration

* Ollama (ROCm) running continuously

---

### 🧪 VFIO / GPU Passthrough

* Fully declarative libvirt hooks
* `prepare`:

  * stops greetd
  * unbinds GPU → vfio-pci
* `release`:

  * rebinds GPU
  * restarts greetd
* Single-GPU:

  * host screen goes black
  * use Looking Glass / SPICE

---

### 🔐 Security

* AppArmor
* Fail2ban (3 SSH fails → 48h ban)
* SSH:

  * password disabled
  * root login disabled
* Firewall enabled

---

### 🔗 Integration

* KDE Connect
* Waydroid
* Flatpak + GNOME Software
* Virt-Manager + Looking Glass

---

## 📁 Repository Structure

```
├── assets/
├── install.sh
├── nixos/
│   ├── flake.nix
│   ├── flake.lock
│   ├── configuration.nix
│   └── home.nix
├── vm-xml/
├── wallpaper/
├── cs2.cfg / csgo.cfg
├── KURULUM.md
└── README.md
```

> ⚠️ `hardware-configuration.nix` is NOT included.

---

## ⚡ Installation

### 1. Clone repo

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-.git
cd Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough-
```

### 2. Generate hardware config

```bash
sudo nixos-generate-config
```

### 3. Run installer

```bash
chmod +x install.sh
./install.sh
```

---

### 4. Create password

```bash
mkpasswd -m sha-512 | sudo tee /etc/nixos/hashedPassword
```

---

### 5. Rebuild system

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## 🧩 Post Install

```bash
waydroid init -f
ollama pull llama3
cat /var/log/libvirt/vfio.log
```

---

## 🎮 Usage

### Gaming

```bash
mangohud gamemoderun gamescope -f -- %command%
```

### VM

* Start via `virt-manager`
* Hooks handle GPU automatically

---

## 🛠️ Maintenance

```bash
snap-root
snap-home
btrfs-df

nrs
nup
nclean
```

---

## 🔄 Non-AMD Hardware

| Component  | Changes                                               |
| ---------- | ----------------------------------------------------- |
| Intel CPU  | `kvm-intel`, `intel_iommu`, remove `amd_pstate`       |
| NVIDIA GPU | enable `hardware.nvidia.modesetting`, remove AMD vars |
| Intel iGPU | use modesetting driver                                |

---

## ⚠️ Important Notes

* Single-GPU VFIO → screen goes black
* Update GPU PCI IDs in config
* SSH requires key login

---

## 📜 License

MIT

---

## 👑 Maintainer

**kUmutUK**

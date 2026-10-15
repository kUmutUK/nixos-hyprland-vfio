# NixOS · Hyprland · AMD GPU Passthrough (VFIO)

A flake-based NixOS gaming desktop that passes its single AMD Radeon GPU through to a Windows 10 virtual machine, while using Hyprland for the host desktop.

> **Target platform:** AMD Ryzen 5 5600 + AMD Radeon RX 6700 XT (Navi 22), UEFI, and a single physical GPU. Other RX 6000/7000 cards are not automatically supported: PCI/IOMMU grouping, GPU reset behavior, and ROCm settings must be verified separately. Intel CPUs and NVIDIA GPUs are outside this configuration's target scope.

## Contents

- [Purpose and safety](#purpose-and-safety)
- [Requirements](#requirements)
- [Installation](#installation)
- [Preparing and starting the VM](#preparing-and-starting-the-vm)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Gaming stack](#gaming-stack)
- [Important configuration decisions](#important-configuration-decisions)
- [Known limitations](#known-limitations)
- [Repository map](#repository-map)
- [Validation](#validation)

## Purpose and safety

The host is used for gaming and daily desktop work. When the VM starts, the QEMU hook stops the host graphical session and attaches the GPU functions to `vfio-pci`. When the VM stops, the hook attempts to return the GPU to the host drivers and restore the session. A failed preparation step should roll back and prevent the VM from starting.

This is a personal, hardware-specific configuration, not a universal NixOS installer. Incorrect disk identifiers can destroy data; incorrect filesystem UUIDs can prevent boot; and a failed single-GPU reset can leave the host without graphics. Back up important data and keep a recovery TTY or SSH path available before testing.

The repository is MIT-licensed and is provided “as is,” without warranty. Use it at your own risk.

## Requirements

| Component | Target / notes |
|---|---|
| CPU | AMD Ryzen desktop CPU. Intel is not supported by this configuration: `kvm-amd`, `amd_iommu`, and `amd_pstate` are AMD-oriented. |
| GPU | AMD Radeon RX 6700 XT (Navi 22) is the documented target. `rocmOverrideGfx = "10.3.0"` is configured for the target system; do not assume it is appropriate for another GPU. |
| Firmware | UEFI. Enable IOMMU / AMD-Vi in firmware and verify it after boot with `dmesg` and `/sys/kernel/iommu_groups/`. |
| Storage | About 810 GiB allocated: 1 GiB EFI, 8 GiB swap, and an 800 GiB LUKS2/Btrfs volume in the reference layout. |
| Filesystems | LUKS2 + Btrfs subvolumes + EFI. The configured disk swap is outside the LUKS volume and is therefore not encrypted. |
| Kernel | CachyOS BORE-LTO selected through a flake input. The exact kernel version follows the locked kernel input. |

The installer checks the GPU's IOMMU group. If unrelated devices share that group, the GPU may not be safely passed through without additional isolation measures. ACS override is not enabled by default.

## Installation

The repository root is intended to become `/etc/nixos/`, while the flake lives in `/etc/nixos/nixos/`.

### Path A — Fresh installation

Follow the Turkish step-by-step guide in [`KURULUM.md`](KURULUM.md) for disk partitioning, LUKS2, Btrfs subvolumes, generating the machine-specific hardware file, setting passwords, and installing NixOS.

The high-level flow is:

```bash
nixos-generate-config --root /mnt

git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/hardware-configuration.nix
rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
cp -r /tmp/repo/. /mnt/etc/nixos/

cd /mnt/etc/nixos/nixos
nix flake lock --update-input cachyos-kernel
nixos-install --flake /mnt/etc/nixos/nixos#nixos --accept-flake-config
```

**Before installing:**

- Replace `nixos/hardware-configuration.nix` with the file generated for the target machine. The repository's original UUIDs and device paths are machine-specific; never use them blindly.
- Create `/mnt/etc/nixos/hashedPassword` as explained in `KURULUM.md`, and restrict its permissions to `0600`. Do not commit this file.
- Review the CachyOS binary-cache trust prompt before accepting it. The flake uses the upstream `release` branch and pinned overlay. The command above updates only the CachyOS input; it does not update every flake input.
- Verify the target disk before running any partitioning command. The installation guide contains destructive operations.

### Path B — Migrate an existing NixOS installation

Run the installer as a normal user with `sudo` privileges:

```bash
chmod +x install.sh  # only needed if the archive lost the executable bit
./install.sh
```

The script backs up existing configuration files, asks for the selected GPU/audio PCI addresses and host-specific values, updates the deployed hook and VM XML, and preserves existing `system.stateVersion` and `home.stateVersion` values when it can identify them. Inspect any warnings before rebuilding. The script deliberately does not overwrite an existing machine-specific hardware configuration without confirmation.

### Activate and reboot

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
sudo reboot
```

Reboot after changing kernel parameters, initrd modules, or VFIO binding configuration. A reboot alone does not prove that IOMMU is enabled; verify it with:

```bash
dmesg | grep -Ei 'AMD-Vi|IOMMU'
find /sys/kernel/iommu_groups/ -maxdepth 2 -type l
```

SSH password authentication is disabled, and no public keys are included by default. Add your own public key to `users.users.localhost.openssh.authorizedKeys.keys` in `nixos/configuration.nix`, or disable `services.openssh` if you do not need SSH.

## Preparing and starting the VM

The VM domain is named `win10`. Before defining or starting it, ensure that the Windows installation ISO, VirtIO driver ISO, and qcow2 disk exist at the paths referenced by `vm-xml/win10.xml`. The XML uses the SATA bus for both CD-ROM drives; the operating-system disk uses VirtIO and needs the VirtIO storage driver during Windows setup.

> **Windows 10 lifecycle:** Standard support for Windows 10 Home and Pro ended on October 14, 2025 ([Microsoft lifecycle policy](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)). Before using this guest for network-connected or sensitive activity, verify that the installed edition is covered by applicable Extended Security Updates (ESU) or its own supported lifecycle (for example, an eligible LTSC edition), and that updates are installed. The ISO filename alone does not establish ESU eligibility.

After the first system activation and reboot, prepare the VM disk and define the domain:

```bash
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu
# Preserve an XML already synchronized by install.sh; it contains this host's PCI addresses.
if [ ! -f /var/lib/libvirt/win10.xml ]; then
  sudo cp /etc/nixos/vm-xml/win10.xml /var/lib/libvirt/win10.xml
else
  echo "Preserving existing deployed VM XML. Verify its GPU/audio PCI addresses before starting the VM."
fi
if [ ! -f /var/lib/libvirt/images/win10new.qcow2 ]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G
fi
sudo chown qemu-libvirtd:qemu-libvirtd /var/lib/libvirt/images/win10new.qcow2
sudo chmod 0660 /var/lib/libvirt/images/win10new.qcow2
sudo virsh define /var/lib/libvirt/win10.xml
```

Use the disk and ISO filenames that actually exist on your host. The XML's PCI addresses must match `GPU_PCI` and `GPU_AUDIO` in `/etc/nixos/nixos/hooks/qemu`; `install.sh` performs this synchronization when run successfully. If you configured the VM manually, verify both PCI host devices with `lspci` and edit the deployed XML accordingly.

The default XML does not configure USB keyboard/mouse passthrough, and it intentionally has no emulated graphics console. Before handing the only GPU to the guest, configure a USB input device or a separate USB controller and verify that you can control the VM without the host desktop.

Start the VM outside the graphical login session because the hook may terminate that session:

```bash
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

Check the unit and hook logs from a separate TTY or SSH session:

```bash
sudo journalctl -u vmstart.service -b --no-pager
sudo cat /var/log/libvirt/vfio.log
sudo journalctl -u libvirtd -f
```

### Temporary VNC diagnostics for the first boot

The helper generates a separate diagnostic XML with loopback-only VNC and a VirtIO video device. It does not overwrite the production XML, qcow2 disk, or NixOS configuration:

```bash
sudo python3 scripts/prepare-vm-diagnostic.py \
  --input /var/lib/libvirt/win10.xml \
  --output /var/lib/libvirt/win10-diagnostic.xml
sudo virsh define /var/lib/libvirt/win10-diagnostic.xml
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

**Important:** the diagnostic XML retains the domain name `win10`, so `virsh define` temporarily replaces the existing domain definition rather than creating a second VM. Once testing is complete, shut down the VM and restore the production definition:

```bash
sudo virsh define /var/lib/libvirt/win10.xml
```

VNC listens only on `127.0.0.1`. Use an SSH tunnel for remote viewing; do not expose VNC on all interfaces.

## Keyboard shortcuts

`SUPER` is the physical Super key (the `$mainMod` modifier).

| Shortcut | Action |
|---|---|
| `SUPER` + `Return` / `C` | Kitty terminal |
| `SUPER` + `A` | Rofi application launcher |
| `SUPER` + `S` / `SHIFT+S` / `CTRL+S` | Pypr scratchpads: terminal / music / file manager |
| `SUPER` + `Q` | Close active window |
| `SUPER` + `F` | Toggle fullscreen |
| `SUPER` + `V` | Toggle floating window |
| `SUPER` + `W` | Waypaper (static wallpaper selector) |
| `SUPER` + `Escape` | Lock screen with Hyprlock |
| `SUPER` + `SHIFT+E` | Exit session |
| `SUPER` + `SHIFT+C` | Hyprpicker color picker |
| `SUPER` + `G` | Toggle window group |
| `SUPER` + `Tab` | Previous workspace |
| `SUPER` + arrow keys / `H J K L` | Move focus between windows |
| `SUPER` + `SHIFT` + arrows / `H J K L` | Move a window |
| `SUPER` + `CTRL` + arrows / `H J K L` | Resize a window |
| `SUPER` + mouse wheel | Cycle windows |
| `SUPER` + left-drag | Move a window |
| `SUPER` + right-drag | Resize a window |
| `SUPER` + `1`…`9`, `0` | Switch to workspaces 1–10 |
| `SUPER` + `SHIFT` + `1`…`0` | Move the active window to a workspace |
| `SUPER` + `P` | Select a region and copy it |
| `SUPER` + `SHIFT+P` | Select a region, annotate with Satty, then copy |
| `SUPER` + `Y` | Toggle WuWa AI automatic translation |
| `SUPER` + `SHIFT+T` | One-shot OCR and Turkish translation |
| `SUPER` + `ALT+T` | Toggle mouse-selection translation |

`SUPER+W` selects a static wallpaper; the desktop's video wallpaper is managed by `mpvpaper.service` and its watchdog. Waypaper does not control `mpvpaper`.

The mouse-selection and one-shot translation scripts use `translate-shell` (`trans`) with a Google Translate backend by default. Selected text is sent over the network; do not use these shortcuts for sensitive text unless you replace the backend with a local workflow.

The WuWa OCR fallback requires the locally installed `wuwa-gemma` model. Start setup manually and wait for it to finish:

```bash
sudo systemctl start wuwa-gemma-init
sudo systemctl status wuwa-gemma-init --no-pager
```

The OCR script now checks that the model is available before beginning; it reports an error instead of treating a `null` response as translated text.

## Gaming stack

| Component | Role |
|---|---|
| RADV | AMD Vulkan driver; `AMD_VULKAN_ICD=RADV`, `RADV_PERFTEST=gpl` |
| `lsfg-vk` | Vulkan frame-generation layer; per-game settings in `~/.config/lsfg-vk/conf.toml` |
| `low_latency_layer` | Vulkan layer using `VK_AMD_anti_lag`, enabled with `LOW_LATENCY_LAYER_REFLEX=1` |
| GameMode | Applies the configured game-time priority and performance settings |
| Gamescope | Fullscreen and window rules for games |
| MangoHud | FPS, frametime, GPU/CPU, and temperature overlay |
| Ananicy-cpp | Process priority rules |
| power-profiles-daemon | Power profile / CPU governor management |
| Steam / Proton / Wine | Windows game compatibility tools |

Both Vulkan layers are configured without an explicit `enable_environment` restriction. Inspect the active layers with:

```bash
VK_LOADER_DEBUG=layer vulkaninfo 2>&1 | grep -iE 'korthos|lsl'
```

## Important configuration decisions

- `systemd-boot` is used; UEFI is required.
- The QEMU hook is installed via `virtualisation.libvirtd.hooks.qemu.vfio`. The path is supplied by NixOS to libvirt's hook mechanism.
- The hook uses an explicit store-path Bash interpreter and controlled `PATH`, since libvirt service environments are minimal.
- `zramSwap.priority = 100` is higher than disk swap priority `10`, so zram is preferred.
- `vm.swappiness = 180` is an intentional aggressive swap tendency, not a priority setting. It can increase major page faults and frametime spikes if disk swap is used.
- `hypridle` requests suspend after 900 seconds; Hyprlock is invoked through the configured pre-sleep command.
- `HYPRLAND_CONFIG` is passed through the greetd environment wrapper, preventing Hyprland from accidentally selecting a different configuration format.
- `nowatchdog` and `nmi_watchdog=0` reduce watchdog-based lockup diagnostics in exchange for less diagnostic data.
- `usbcore.autosuspend=-1` disables USB autosuspend and may increase idle power consumption.
- `kvm.ignore_msrs=1` suppresses failures from some unknown MSR accesses but can hide guest MSR problems.

## Known limitations

- **Navi 2x reset behavior:** reliable reset and host rebind cannot be guaranteed from static analysis. The optional `remove`/`rtcwake`/`rescan` recovery path is disabled by default. Enabling `VFIO_ALLOW_SUSPEND_RECOVERY=1` can suspend the host briefly and should only be attempted after checking firmware support and arranging recovery access.
- **Single-GPU host:** while the VM owns the GPU, the host does not have a normal graphical session. Keep a recovery TTY or SSH session available.
- **Fixed host user:** the hook defaults to `localhost` and terminates that user's graphical sessions. This is designed for this single-user configuration.
- **No automatic USB input passthrough:** configure your own keyboard/mouse or a dedicated USB controller. Do not copy the maintainer's commented VID:PID example blindly.
- **Unencrypted swap:** the disk swap partition sits outside LUKS2.
- **OCR display geometry:** default WuWa crop regions target a 2560×1440 display. The script validates configured geometry and can be overridden with `WUWA_GEOMETRY_MAIN` and `WUWA_GEOMETRY_CHOICE`.
- **Windows 10 lifecycle:** standard support has ended; see the lifecycle warning above and verify the guest edition’s ESU/LTSC status before using it online.
- `assets/` is intentionally absent; active configuration files do not reference it.

## Repository map

```text
.
├── README.md
├── KURULUM.md                      # Turkish fresh-install guide
├── DEGISIKLIK_GECMISI.md           # Turkish detailed legacy changelog
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
├── install.sh                      # migration/update helper for an existing NixOS host
├── .github/workflows/check.yml
├── docs/
│   ├── REPAIR-AND-VALIDATION-REPORT.md
│   └── archive/                    # English historical audit summaries
├── scripts/
│   ├── extract-embedded-scripts.py
│   ├── prepare-vm-diagnostic.py
│   ├── test-installer-invariants.sh
│   ├── test-vfio-hook-driver-state.sh
│   └── test-vm-xml.py
├── vm-xml/win10.xml
└── nixos/
    ├── flake.nix
    ├── flake.lock
    ├── configuration.nix
    ├── home.nix
    ├── hardware-configuration.nix   # machine-specific: replace for another host
    └── hooks/qemu
```

Hyprland, Hyprlock, Waybar, Pyprland, MangoHud, lsfg-vk, and helper scripts are declared inline in `nixos/home.nix`; there is no parallel config tree for those entries.

## Validation

Run from the repository root:

```bash
nix develop ./nixos
nixfmt ./nixos
shellcheck -S warning install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh
python3 scripts/extract-embedded-scripts.py /tmp/embedded-scripts | xargs -0 -r -n1 -- shellcheck -S warning
python3 scripts/test-vm-xml.py
bash scripts/test-vfio-hook-driver-state.sh
bash scripts/test-installer-invariants.sh
(cd nixos && nix flake check --no-build)
```

`nix flake check --no-build` evaluates the flake but does not build the complete system or kernel. It does not replace a full build, libvirt domain validation, or the physical GPU lifecycle test: start the VM, shut it down normally, start it a second time, and verify that the host graphical session recovers.

## License

MIT. See [`LICENSE`](LICENSE).

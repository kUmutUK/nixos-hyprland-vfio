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

This is a personal, hardware-specific configuration, not a universal NixOS installer. The included configuration sets `networking.hostName = "nixos"`; change it in `nixos/configuration.nix` if the target host should use a different name. Incorrect disk identifiers can destroy data; incorrect filesystem UUIDs can prevent boot; and a failed single-GPU reset can leave the host without graphics. Back up important data and keep a physical recovery TTY available before testing. SSH password login is enabled for the normal `localhost` account only, root login is disabled, and the QEMU hook terminates only the local `seat0` sessions so a headless SSH session should survive VM startup. Test remote access before relying on it; the hook will abort and roll back if a process still holds the GPU device nodes.

The repository is MIT-licensed and is provided “as is,” without warranty. Use it at your own risk.

## Requirements

| Component | Target / notes |
|---|---|
| CPU | AMD Ryzen desktop CPU. Intel is not supported by this configuration: `kvm-amd` and `amd_pstate` are AMD-oriented. |
| GPU | AMD Radeon RX 6700 XT (Navi 22) is the documented target. `rocmOverrideGfx = "10.3.0"` is configured for the target system; do not assume it is appropriate for another GPU. |
| Firmware | UEFI. Enable IOMMU / AMD-Vi in firmware and verify it after boot with `dmesg` and `/sys/kernel/iommu_groups/`. |
| Storage | The reference partitions total 809 GiB: 1 GiB EFI, 8 GiB swap, and an 800 GiB LUKS2/Btrfs volume. Use a disk of at least 810 GiB (about 870 GB decimal); a 1 TB-class disk is recommended. |
| Filesystems | LUKS2 + Btrfs subvolumes + EFI. Disk swap sits outside the LUKS volume; the reference config encrypts it with a per-activation random key using `randomEncryption.enable = true`. Preserve that option in the generated hardware file for fresh installs. |
| Kernel | CachyOS RT-Bore-LTO (real-time patch set + BORE scheduler + ThinLTO), selected through the upstream `master` flake input. The kernel version is not hard-coded; the lock file records the selected input revision until you intentionally update it. Upstream does not publish this LTO variant to its binary cache, so it must be built locally. |

The active `boot.kernelParams` list does not set `amd_iommu=on` or `iommu=pt`. Enable IOMMU / AMD-Vi in firmware, then verify runtime support instead of assuming that the VFIO configuration alone enables it. The installer requires resolvable IOMMU groups for both the GPU and its audio function and aborts before deploying configuration files if either group is missing. If unrelated devices share a group, the installer requires explicit typed confirmation after showing group members; this confirmation does not make unsafe isolation safe. ACS override is not enabled by default.

## Installation

> **Recommended for everyone: use the manual installation steps first.** Review each file and command before applying it. `install.sh` is an optional, higher-risk migration helper for an already-installed NixOS system; it is not the default recommendation and is not for partitioning or fresh OS installation. It writes system configuration and VM XML, can make the host or VM unusable if the hardware/settings are wrong, and cannot guarantee that rollback will recover every state. See the explicit risk notice in the script and [`DISCLAIMER.md`](DISCLAIMER.md).

### Path A — Manual fresh installation (recommended for a new system)

Follow the English [`INSTALLATION.md`](INSTALLATION.md) guide from the NixOS Live ISO. `KURULUM.md` is retained only as an English compatibility pointer for older links. The guides cover partitioning, LUKS2, Btrfs subvolumes, machine-specific hardware configuration, password setup, and installation. The disk steps are **destructive**; do not copy them without substituting and re-checking your own target disk.

The high-level flow is shown below. Perform the steps in [`INSTALLATION.md`](INSTALLATION.md) in order; do not skip the disk identity checks or typed confirmations.

```bash
set -Eeuo pipefail
sudo nixos-generate-config --root /mnt

git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/hardware-configuration.nix
TARGET_BACKUP="/mnt/etc/nixos-generated-backup-$(date +%Y%m%d-%H%M%S)"
if [ -e "$TARGET_BACKUP" ] || [ -L "$TARGET_BACKUP" ]; then
  echo "ERROR: Backup path already exists: $TARGET_BACKUP" >&2
  exit 1
fi
sudo mv /mnt/etc/nixos "$TARGET_BACKUP"
sudo mkdir -p /mnt/etc/nixos
# Copy the repository contents but leave Git metadata out of the system config tree.
tar --exclude='./.git' -C /tmp/repo -cf - . | sudo tar --no-same-owner -C /mnt/etc/nixos -xf -

# Preserve the generated swap device path and add randomEncryption.enable = true
# inside its swapDevices entry, then save and exit the editor.
sudoedit /mnt/etc/nixos/nixos/hardware-configuration.nix
HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
sudo chown root:root /mnt/etc/nixos/hashedPassword
sudo chmod 600 /mnt/etc/nixos/hashedPassword
sudo test -s /mnt/etc/nixos/hashedPassword || { echo "hashedPassword is missing or empty" >&2; exit 1; }
[ "$(sudo stat -c '%U:%G:%a' /mnt/etc/nixos/hashedPassword)" = "root:root:600" ] || { echo "hashedPassword must be root:root mode 600" >&2; exit 1; }
cd /mnt/etc/nixos/nixos
sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos
```

**Before installing:**

- Replace `nixos/hardware-configuration.nix` with the file generated for the target machine. The repository's original UUIDs and device paths are machine-specific; never use them blindly.
- Confirm `/mnt/etc/nixos/hashedPassword` exists and has permissions `0600`. Do not commit this file.
- Review the Nix Community binary-cache trust prompt before accepting it. The current flake configures `https://nix-community.cachix.org`; it does not configure the upstream CachyOS Attic cache. The flake follows the upstream `master` branch for CachyOS and uses `overlays.pinned`; no kernel version is hard-coded in `flake.nix`, and `nixos/flake.lock` records the resolved input revision. RT-Bore-LTO ThinLTO is not published in the upstream CachyOS binary cache, so expect a local kernel build.

  To update the running system after its first boot, first save the deployed lock, then update only this input and inspect the diff before rebuilding:

  ```bash
  sudo cp /etc/nixos/nixos/flake.lock /tmp/flake.lock.before-cachyos-update
  sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel
  sudo diff -u /tmp/flake.lock.before-cachyos-update /etc/nixos/nixos/flake.lock || test "$?" -eq 1
  ```

  A `diff` exit status of 1 means changes were found; status 2 indicates an error. Review any cache-trust prompt before accepting settings. Do not run commands targeting `/etc/nixos/nixos` from a Live ISO; for an intentional candidate update before first installation, target `/mnt/etc/nixos/nixos` instead.
- For the first boot, review the `system.stateVersion` and `home.stateVersion` values rather than changing them just to match the installed release.
- Verify the target disk before running any partitioning command. [`INSTALLATION.md`](INSTALLATION.md) contains commands that erase a partition table and format filesystems.

### Path B — Manual migration of an existing NixOS installation (recommended)

This is the recommended path for an existing host. It intentionally makes you inspect changes instead of letting a script replace files in one pass.

1. **Do not continue while the Windows VM is running.** Save your work, shut down `win10` cleanly if it exists, and keep physical/recovery-console access available. Back up important personal data separately; the configuration backup below is not a full system backup.
2. Use a repository checkout outside `/etc/nixos`, for example `~/nixos-hyprland-vfio`, and keep the existing machine-specific `hardware-configuration.nix` and password hash.
3. Back up current NixOS settings, the deployed VM XML if present, and the Home Manager directories that this configuration may manage:

```bash
set -Eeuo pipefail
REPO="$HOME/nixos-hyprland-vfio"   # change this if your checkout is elsewhere
test -f "$REPO/nixos/configuration.nix"
BACKUP="$HOME/.nixos-manual-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 -- "$BACKUP"
sudo cp -a -- /etc/nixos "$BACKUP/etc-nixos"
if sudo test -f /var/lib/libvirt/win10.xml; then
  sudo cp -a -- /var/lib/libvirt/win10.xml "$BACKUP/win10.xml"
fi
for path in /home/localhost/.config/hypr /home/localhost/.config/waybar \
            /home/localhost/.config/gtk-3.0 /home/localhost/.config/gtk-4.0; do
  if sudo test -e "$path"; then
    sudo cp -a -- "$path" "$BACKUP/$(basename "$path")"
  fi
done
printf 'Backup saved to %s\n' "$BACKUP"
```

4. **Review the diff before copying anything.** This command only displays differences; exit code 1 from `diff` means differences were found, not a command failure:

```bash
REPO="$HOME/nixos-hyprland-vfio"   # same checkout path as above
for file in configuration.nix home.nix flake.nix flake.lock lsfg-vk-v2.nix; do
  target="/etc/nixos/nixos/$file"
  if [ -f "$target" ]; then
    diff -u "$target" "$REPO/nixos/$file" || test "$?" -eq 1
  else
    printf 'No existing target: %s\n' "$target"
  fi
done
# Record current compatibility baselines BEFORE replacing configuration files.
grep -nE 'system\.stateVersion|home\.stateVersion' \
  /etc/nixos/configuration.nix /etc/nixos/home.nix \
  /etc/nixos/nixos/configuration.nix /etc/nixos/nixos/home.nix \
  /home/localhost/.config/home-manager/home.nix 2>/dev/null || true
```

5. After reviewing that diff and the values above, copy the five required Nix source files, including the LSFG-VK v2 package expression imported by both `flake.nix` and `configuration.nix`. This overwrites their corresponding target files, so do not run it before making and checking the backup:

```bash
REPO="$HOME/nixos-hyprland-vfio"   # same checkout path as above
sudo install -d -m 0755 /etc/nixos/nixos
for file in configuration.nix home.nix flake.nix flake.lock lsfg-vk-v2.nix; do
  sudo install -m 0644 "$REPO/nixos/$file" /etc/nixos/nixos/
done
sudo install -d -m 0755 /etc/nixos/nixos/hooks
sudo install -m 0755 "$REPO/nixos/hooks/qemu" /etc/nixos/nixos/hooks/qemu
```

6. **Preserve machine-specific settings.** If `/etc/nixos/nixos/hardware-configuration.nix` does not exist, first verify that `/etc/nixos/hardware-configuration.nix` was generated on this machine, then copy it (never use the repository template as a substitute):

```bash
if [ ! -f /etc/nixos/nixos/hardware-configuration.nix ]; then
  test -f /etc/nixos/hardware-configuration.nix || { echo "No machine-generated hardware-configuration.nix; stop and generate/review one first." >&2; exit 1; }
  sudo install -m 0644 /etc/nixos/hardware-configuration.nix /etc/nixos/nixos/hardware-configuration.nix
fi
```

**Preserve machine-specific settings.** Never copy `REPO/nixos/hardware-configuration.nix` just because the file exists in the repository. Use the file generated on this machine. If `/etc/nixos/nixos/hardware-configuration.nix` already exists, compare its UUIDs, mount points, and swap device with the generated `/etc/nixos/hardware-configuration.nix` and merge deliberately; do not blindly replace either. Edit `/etc/nixos/nixos/configuration.nix` and `/etc/nixos/nixos/home.nix` to preserve the previous `system.stateVersion` and `home.stateVersion` values, then review the `home.nix` values listed in [`INSTALLATION.md`](INSTALLATION.md) (`gitName`, `gitEmail`, monitor output, monitor rule, and wallpaper path).

7. Find the GPU display and HDMI/DP audio functions with `lspci -Dnn`. Edit `/etc/nixos/nixos/hooks/qemu` so `GPU_PCI` and `GPU_AUDIO` match the actual PCI addresses. Validate IOMMU groups and make sure no unrelated device shares an unsafe group before using passthrough.

8. For an existing VM, **do not replace its XML with the repository template**. Preserve its UUID, MAC, firmware/NVRAM and primary Windows disk path. The `scripts/sync-vm-xml.py` helper backs up and preserves an existing deployed XML while synchronizing only the two GPU/audio PCI addresses. For a new VM, use the helper in [Preparing and starting the VM](#preparing-and-starting-the-vm) instead of copying the template directly; it generates a fresh UUID and MAC and leaves the source template unchanged. Review the disk/ISO paths and USB IDs before defining the XML. Define it with `sudo virsh define /var/lib/libvirt/win10.xml` after the guest is shut down.

9. Check the password file, run the test suite available on the host, and build before switching:

```bash
bash -n "$REPO/install.sh"
bash "$REPO/scripts/test-installer-invariants.sh"
bash "$REPO/scripts/test-installer-rollback.sh"
bash "$REPO/scripts/test-vfio-hook-driver-state.sh"
python3 "$REPO/scripts/test-vm-xml.py"
python3 "$REPO/scripts/test-vm-xml-sync.py"
python3 "$REPO/scripts/test-vm-diagnostic.py"
sudo nixos-rebuild build --flake /etc/nixos/nixos#nixos
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

Only after reviewing the build and dry-activation output should you run `sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos`. Keep the backup and a working recovery generation until you have verified boot, graphics login, SSH access, and the complete VM start/shutdown/display-recovery cycle.

### Path C — Optional `install.sh` migration helper (advanced users only; not the default recommendation)

Use this only if you have reviewed the script and intentionally prefer its automated migration flow over the manual steps above. It is **not** a fresh-installer or disk-partitioning tool. It replaces source files under `/etc/nixos/nixos` (including `/etc/nixos/nixos/hooks/qemu`) and writes `/var/lib/libvirt/win10.xml`; it does **not** directly replace the currently active libvirt hook or automatically define the updated VM XML. The active hook is generated from `nixos/configuration.nix` and is refreshed only after a successful NixOS rebuild/activation. When `/var/lib/libvirt/win10.xml` already exists, the helper now uses that file as its source and changes only the two PCI hostdev source addresses; it retains other XML settings, including custom CPU, firmware/NVRAM, device and disk configuration. The deployed XML is backed up first. If the existing XML is malformed, belongs to another domain, has an unsupported primary-disk layout, or does not contain exactly two synchronizable PCI hostdevs, the helper aborts so you can use the manual path. On a new VM, it starts from the repository template. Incorrect PCI addresses, state versions, or mount settings can still make the host or VM unusable. Backup/rollback remains best-effort and does not replace a full backup or a tested recovery method. The script does not automatically rebuild/activate the host, define the VM XML, or reboot, and it retains prior installer backups without automatically deleting them. Do not run it as root; keep its repository checkout outside `/etc/nixos`.

```bash
# Review the whole script and the manual migration section first.
less install.sh
bash -n install.sh
./install.sh
```

The installer displays a risk notice and requires the exact acknowledgement phrase shown by the script. If you do not fully understand or accept the changes, cancel and use Path B. Maintainers creating a source ZIP should use the canonical Git archive command below; it excludes `.git` and preserves `install.sh`'s executable bit. CI validates this archive and uploads this exact ZIP as a file in the `nixos-hyprland-vfio-source` workflow artifact; distribute that verified archive instead of independently repackaging the checkout:

```bash
git archive --format=zip --prefix=nixos-hyprland-vfio/ \
  --output=nixos-hyprland-vfio.zip HEAD
```

### Activate and reboot

Before rebuilding, make sure `/etc/nixos/hashedPassword` exists and contains a
valid password hash. `localhost` uses this file via `hashedPasswordFile`; if it is
missing, the account can remain locked and Hyprland login will fail. Preserve an
existing valid hash. Only create a new one if the file is missing or empty:

```bash
if [ ! -s /etc/nixos/hashedPassword ]; then
  HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
  printf '%s\n' "$HASH" | sudo tee /etc/nixos/hashedPassword >/dev/null
fi
sudo chown root:root /etc/nixos/hashedPassword
sudo chmod 600 /etc/nixos/hashedPassword
sudo test -s /etc/nixos/hashedPassword || { echo "hashedPassword is missing or empty" >&2; exit 1; }
password_meta=$(sudo stat -c '%U:%G:%a' /etc/nixos/hashedPassword) || { echo "Cannot inspect hashedPassword metadata" >&2; exit 1; }
[ "$password_meta" = "root:root:600" ] || { echo "hashedPassword must be owned by root:root with mode 600 (found: $password_meta)" >&2; exit 1; }
```

Then activate and reboot:

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

OpenSSH is enabled on TCP port 22, and the firewall allows that port. Password authentication is enabled for `localhost` only; root login is disabled, interactive keyboard authentication and X11 forwarding are disabled, and Fail2ban watches failed SSH attempts. This is still an exposed authentication surface: use a strong, unique account password, restrict SSH at your network edge, and do not expose port 22 to untrusted networks. Prefer adding your own public key to `users.users.localhost.openssh.authorizedKeys.keys`; after confirming key login works from a separate session, disable password authentication. The QEMU hook now terminates only local `seat0` sessions, not all sessions for the user, so a headless SSH session should remain connected during GPU handoff. Keep a physical recovery TTY available and test this on your host before relying on it. Connect from another trusted device with `ssh localhost@<host-ip>` (find the address with `ip -br address`). After changing session variables or SSH options, rebuild and start a fresh login session before testing.

## Preparing and starting the VM

The VM domain is named `win10`. The default `vm-xml/win10.xml` expects these files under `/var/lib/libvirt/images/`: `Win10_22H2_English_x64v1.iso`, `virtio-win-0.1.285.iso`, and `win10new.qcow2`. Confirm that the ISO files you downloaded match the XML paths; edit the XML if their names or locations differ. The XML uses the SATA bus for both CD-ROM drives; the operating-system disk uses VirtIO and needs the VirtIO storage driver during Windows setup.

> **Windows 10 lifecycle:** Standard support for Windows 10 Home and Pro ended on October 14, 2025 ([Microsoft lifecycle policy](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)). Before using this guest for network-connected or sensitive activity, verify that the installed edition is covered by applicable Extended Security Updates (ESU) or its own supported lifecycle (for example, an eligible LTSC edition), and that updates are installed. The ISO filename alone does not establish ESU eligibility.

After the first system activation and reboot, prepare the VM disk and define the domain. Run the following block from the repository root, after reviewing the XML's disk/ISO paths and USB passthrough IDs. Enter the exact `GPU_PCI` and `GPU_AUDIO` values from the deployed hook at `/etc/nixos/nixos/hooks/qemu`:

```bash
set -euo pipefail
REPO="$(pwd)"
VM_XML=/var/lib/libvirt/win10.xml
test -f "$REPO/scripts/sync-vm-xml.py"
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu

# Remember whether this is an existing VM before the helper writes/updates its XML.
if sudo test -e "$VM_XML" || sudo test -L "$VM_XML"; then
  EXISTING_VM_XML=1
else
  EXISTING_VM_XML=0
fi

read -rp "GPU display PCI address from /etc/nixos/nixos/hooks/qemu: " GPU_PCI
read -rp "GPU audio PCI address from /etc/nixos/nixos/hooks/qemu: " GPU_AUDIO
sudo python3 "$REPO/scripts/sync-vm-xml.py" \
  "$GPU_PCI" "$GPU_AUDIO" \
  "$REPO/vm-xml/win10.xml" "$VM_XML"

# Read the primary disk path from the synchronized XML; do not assume a filename.
DISK_PATH="$(sudo python3 - "$VM_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
disks = root.findall("./devices/disk[@device='disk']")
if len(disks) != 1:
    raise SystemExit("Expected exactly one primary disk; inspect the VM XML manually.")
source = disks[0].find("source")
path = source.get("file") if source is not None else None
if not path or not path.startswith("/"):
    raise SystemExit("The primary disk has no absolute file path; inspect the VM XML manually.")
print(path)
PY
)"
echo "Primary disk path in $VM_XML: $DISK_PATH"

if [ "$EXISTING_VM_XML" -eq 1 ]; then
  # Never replace or change permissions on a disk belonging to an existing VM.
  if ! sudo test -f "$DISK_PATH"; then
    echo "ERROR: Existing VM disk is missing: $DISK_PATH" >&2
    echo "Restore/find the original disk or repair the XML manually; no replacement was created." >&2
    exit 1
  fi
  echo "Preserving existing VM disk and its permissions: $DISK_PATH"
  echo "Verify that the configured libvirt/QEMU service can read and write this file before starting the VM."
else
  # Only auto-create the reviewed default disk for a genuinely new deployment.
  if [ "$DISK_PATH" != "/var/lib/libvirt/images/win10new.qcow2" ]; then
    echo "ERROR: New XML references a non-default disk path: $DISK_PATH" >&2
    echo "Review its size and create/configure it manually; refusing to guess." >&2
    exit 1
  fi
  if sudo test -e "$DISK_PATH" || sudo test -L "$DISK_PATH"; then
    echo "ERROR: A disk file already exists but no deployed VM XML was present: $DISK_PATH" >&2
    echo "Verify the file's identity and configure it manually; refusing to adopt it implicitly." >&2
    exit 1
  fi
  sudo qemu-img create -f qcow2 "$DISK_PATH" 120G
  sudo chown qemu-libvirtd:qemu-libvirtd "$DISK_PATH"
  sudo chmod 0660 "$DISK_PATH"
fi

# The XML's Windows and VirtIO ISO source paths must also point to existing files.
sudo virsh define "$VM_XML"
```

The helper creates a fresh UUID and MAC when the deployed XML does not exist. If it already exists, the helper makes a timestamped backup, preserves the existing VM settings and changes only the two GPU/audio PCI addresses. It refuses to replace a symlink, malformed XML, a different VM domain, or an unsupported disk/PCI layout. It never edits `vm-xml/win10.xml`. The disk setup above reads the actual primary disk path from the synchronized XML: existing VM disks are preserved and are never auto-created, re-owned, or re-permissioned; a missing disk for an existing VM stops for manual recovery. Automatic creation is limited to the reviewed 120G default path for a new VM. Verify the Windows and VirtIO ISO paths in the deployed XML exist before starting the guest. The XML's PCI addresses must match `GPU_PCI` and `GPU_AUDIO` in `/etc/nixos/nixos/hooks/qemu`; `install.sh` performs this synchronization when run successfully.

The default XML contains two active USB passthrough entries with fixed vendor/product IDs `1532:0098` and `05ac:024f`; they are not detected or substituted automatically by the installer. Confirm with `lsusb` that these IDs identify the devices you intend to pass through, and edit or remove the corresponding USB `<hostdev>` entries in `/var/lib/libvirt/win10.xml` before starting the VM if they do not. The XML intentionally has no emulated graphics console, so verify that the guest has a usable display and input path before handing it the only GPU.

Start the VM outside the graphical login session because the hook may terminate that session:

```bash
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

Check the unit and hook logs from a physical recovery TTY or SSH. The hook ends only local `seat0` sessions, so SSH sessions should remain available; however, any process still holding the GPU causes the handoff to abort rather than being forcibly terminated:

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
| `SUPER` + `Escape` | Lock screen with Hyprlock |
| `SUPER` + `SHIFT+E` | Exit session |
| `SUPER` + `SHIFT+C` | Hyprpicker color picker |
| `SUPER` + `G` | Toggle window group |
| `SUPER` + `Tab` | Previous workspace |
| `SUPER` + arrow keys / `H J K L` | Move focus between windows |
| `SUPER` + `SHIFT` + arrows / `H J K L` | Move a window |
| `SUPER` + `CTRL` + arrows / `H J K L` | Resize a window |
| `SUPER` + mouse wheel | Cycle workspaces |
| `SUPER` + left-drag | Move a window |
| `SUPER` + right-drag | Resize a window |
| `SUPER` + `1`…`9`, `0` | Switch to workspaces 1–10 |
| `SUPER` + `SHIFT` + `1`…`0` | Move the active window to a workspace |
| `SUPER` + `P` | Select a region and copy it |
| `SUPER` + `SHIFT+P` | Select a region, annotate with Satty, then copy |
| `SUPER` + `Y` | Toggle WuWa AI automatic translation |
| `SUPER` + `SHIFT+T` | One-shot OCR and Turkish translation |
| `SUPER` + `ALT+T` | Toggle mouse-selection translation |

The mouse-selection and one-shot translation scripts use `translate-shell` (`trans`) with a Google Translate backend by default. Selected text is sent over the network; do not use these shortcuts for sensitive text unless you replace the backend with a local workflow.

The WuWa OCR fallback uses the custom Ollama alias `wuwa-gemma`, based on `aya-expanse:8b` (not the Gemma model family). The model is pulled when you start its setup service manually; wait for setup to finish:

```bash
sudo systemctl start wuwa-gemma-init
sudo systemctl status wuwa-gemma-init --no-pager
```

The OCR script now checks that the model is available before beginning; it reports an error instead of treating a `null` response as translated text.

## Gaming stack

| Component | Role |
|---|---|
| RADV | AMD Vulkan driver; `AMD_VULKAN_ICD=RADV`, `RADV_PERFTEST=gpl` |
| `lsfg-vk` | LSFG-VK v2 frame-generation layer, Qt UI and CLI; per-game settings in `~/.config/lsfg-vk/conf.toml` |
| `low_latency_layer` | Vulkan latency layer enabled system-wide through the PAM session variable `LOW_LATENCY_LAYER=1`. It keeps the default AMD Anti-Lag (`VK_AMD_anti_lag`) interface, appropriate for native Linux applications such as CS2. Proton games that need Reflex can opt in per game with `LOW_LATENCY_LAYER_REFLEX=1 %command%`. Use `DISABLE_LOW_LATENCY_LAYER=1 %command%` to opt an incompatible game out. |
| GameMode | Applies the configured game-time priority and performance settings |
| Gamescope | Fullscreen and window rules for games |
| MangoHud | FPS, frametime, GPU/CPU, and temperature overlay |
| Ananicy-cpp | Process priority rules |
| power-profiles-daemon | Power profile / CPU governor management |
| Steam / Proton / Wine | Windows game compatibility tools |

The upstream Vulkan manifest defines `enable_environment` for `LOW_LATENCY_LAYER=1` and `disable_environment` for `DISABLE_LOW_LATENCY_LAYER=1`. The system session sets only `LOW_LATENCY_LAYER=1`, so the layer uses its default AMD Anti-Lag interface globally. For a compatible Proton game that needs Reflex, try `LOW_LATENCY_LAYER_REFLEX=1 %command%` in that game's Steam launch options. If Reflex does not appear in the game's settings, upstream suggests trying `DXVK_CONFIG="dxgi.hideAmdGpu = True"` as an additional per-game option; add it only when needed. To disable the layer for one incompatible game, launch it with `DISABLE_LOW_LATENCY_LAYER=1 %command%`. Inspect active layers with:

**CS2 / Source 2 note:** the upstream [`low_latency_layer` v0.2.0 release notes](https://github.com/Korthos-Software/low_latency_layer/releases/tag/v0.2.0) document frame-pacing issues when an in-engine FPS cap is enabled. While the layer is active, use `fps_max 0` in CS2 until upstream resolves the issue; an external cap such as MangoHud's has been reported not to trigger it. If you still see stutter or frame-pacing problems, opt CS2 out with `DISABLE_LOW_LATENCY_LAYER=1 %command%` and compare frametimes.

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
- `HYPRLAND_CONFIG` is passed through the greetd wrapper and points to the native Lua config generated from `nixos/home.nix` at `~/.config/hypr/hyprland.lua`.
- `nowatchdog` and `nmi_watchdog=0` reduce watchdog-based lockup diagnostics in exchange for less diagnostic data.
- `usbcore.autosuspend=-1` and `kvm.ignore_msrs=1` are **not enabled by default** in `nixos/configuration.nix`. The former disables USB autosuspend and may increase idle power consumption; the latter suppresses some unknown MSR access failures and can hide guest problems. Add either only when the target hardware/guest needs it and after considering the trade-offs.

## Known limitations

- **RT-Bore-LTO validation:** the upstream source does not publish the ThinLTO variant in its binary cache, so each newly selected upstream revision needs a local build. The project owner reports that the currently locked revision built and passed the VM start/shutdown and Hyprland-recovery check on the target machine (see the 2026-10-23 update below); this result is owner-reported, not independently reproduced, and does not guarantee compatibility on other hardware. Real-time preemption does not guarantee higher FPS or better frametimes. Retain a known-good boot generation when testing future kernel revisions.
- **Global Vulkan latency layer compatibility:** upstream `low_latency_layer` v0.2.0 documents an incompatibility with the `obs_vkcapture` Vulkan capture layer. If game capture or recording breaks while the layer is enabled, launch the affected game with `DISABLE_LOW_LATENCY_LAYER=1 %command%` and verify whether capture works again.
- **Navi 2x reset behavior:** reliable reset and host rebind cannot be guaranteed from static analysis. The optional `remove`/`rtcwake`/`rescan` recovery path is disabled by default. Enabling `VFIO_ALLOW_SUSPEND_RECOVERY=1` can suspend the host briefly and should only be attempted after checking firmware support and arranging recovery access.
- **Single-GPU host:** while the VM owns the GPU, the host does not have a normal graphical session. Keep a physical recovery TTY available. The hook ends only local `seat0` sessions and is designed to preserve SSH sessions. The device-node usage check still fails closed if a process retains the GPU, so test the full VM lifecycle on the target hardware.
- **Local graphical-session scope:** the hook runs `loginctl terminate-seat seat0`; it ends local sessions on that seat without filtering by user, and does not target SSH sessions with that command. This is designed for a single-GPU host where the desktop must release the GPU.
- **Fixed USB passthrough IDs:** the default VM XML actively passes through USB IDs `1532:0098` and `05ac:024f`. The installer synchronizes GPU/audio PCI addresses only; it does not discover, validate, or replace these USB IDs. Verify them with `lsusb` and edit/remove the XML entries if they are not the intended devices.
- **Swap outside LUKS2:** the reference `hardware-configuration.nix` enables per-activation random swap encryption (`randomEncryption.enable = true`). A fresh install must preserve this option in the machine-specific generated hardware file. If it is missing or disabled, the disk swap is unencrypted; random swap encryption is not persistent-key LUKS encryption.
- **OCR display geometry:** default WuWa crop regions target a 2560×1440 display. The script validates configured geometry and can be overridden with `WUWA_GEOMETRY_MAIN` and `WUWA_GEOMETRY_CHOICE`.
- **Windows 10 lifecycle:** standard support has ended; see the lifecycle warning above and verify the guest edition’s ESU/LTSC status before using it online.
- `assets/` is intentionally absent; active configuration files do not reference it.

## Repository map

```text
.
├── .gitignore
├── README.md
├── KURULUM.md                      # English compatibility pointer to INSTALLATION.md
├── INSTALLATION.md                 # English fresh-install guide
├── DEGISIKLIK_GECMISI.md           # English current-state summary + archive pointer
├── CONTRIBUTING.md
├── CHANGELOG.md
├── DISCLAIMER.md
├── LICENSE
├── install.sh                      # migration/update helper for an existing NixOS host
├── .github/workflows/check.yml
├── docs/
│   ├── REPAIR-AND-VALIDATION-REPORT.md
│   └── archive/                    # Historical audits and original Turkish release history
├── scripts/
│   ├── extract-embedded-scripts.py
│   ├── prepare-vm-diagnostic.py
│   ├── test-installer-invariants.sh
│   ├── test-installer-rollback.sh
│   ├── test-lsfg-vk-v2.py
│   ├── test-vfio-hook-driver-state.sh
│   ├── sync-vm-xml.py
│   ├── test-vm-diagnostic.py
│   ├── test-vm-xml-sync.py
│   └── test-vm-xml.py
├── vm-xml/win10.xml
└── nixos/
    ├── flake.nix
    ├── flake.lock
    ├── configuration.nix
    ├── home.nix
    ├── hardware-configuration.nix   # machine-specific: replace for another host
    ├── lsfg-vk-v2.nix
    └── hooks/qemu
```

Hyprland's native Lua configuration, Hyprlock, Waybar, Pyprland, MangoHud, the LSFG-VK v2 profile file, and helper scripts are declared in `nixos/home.nix`; there is no parallel Hyprland config file to keep in sync. The LSFG-VK UI/CLI and Vulkan layer are built from a pinned upstream v2 source by `nixos/lsfg-vk-v2.nix`. The generated `conf.toml` is Home Manager-managed: edit profiles in `nixos/home.nix` and rebuild rather than trying to save GUI edits over the read-only Nix store link. Upstream LSFG-VK v2 is licensed CC BY-NC-ND 4.0 (non-commercial/no-derivatives) and is therefore treated as unfree by Nix; this configuration explicitly allows unfree packages. Lossless Scaling itself is not redistributed and must be separately owned/installed through Steam.

## Validation

Run from the repository root. First enter the project's development shell:

```bash
nix develop ./nixos
```

Then, inside that shell, run the validation commands:

```bash
set -euo pipefail
# Check formatting without modifying any files.
find ./nixos -type f -name '*.nix' -print0 | xargs -0 -r -n1 nixfmt --check
shellcheck -S warning install.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-rollback.sh
python3 scripts/test-lsfg-vk-v2.py
python3 scripts/test-vm-xml.py
python3 scripts/test-vm-xml-sync.py
python3 scripts/test-vm-diagnostic.py
bash scripts/test-vfio-hook-driver-state.sh
bash scripts/test-installer-invariants.sh
bash scripts/test-installer-rollback.sh
(
  set -euo pipefail
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  python3 scripts/extract-embedded-scripts.py "$tmpdir" > "$tmpdir/paths.nul"
  mapfile -d '' -t embedded_scripts < "$tmpdir/paths.nul"
  if [ "${#embedded_scripts[@]}" -ne 7 ]; then
    printf 'Expected 7 embedded Bash scripts, found %s\n' "${#embedded_scripts[@]}" >&2
    exit 1
  fi
  shellcheck -S warning "${embedded_scripts[@]}"
)
(cd nixos && nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false)
```
`nixfmt --check` is read-only and fails when a Nix file needs formatting; it does not rewrite source files. To format intentionally, run `nixfmt` without `--check` on the selected files and review `git diff` before committing. `nix flake check --no-build` evaluates the flake but does not build the complete system or kernel. The flags above match the CI evaluation step and prevent lock-file updates during the check. This check does not replace a full build or a physical GPU lifecycle test.

### Prior target-system hardware validation — 2026-10-16

> **Historical scope as of 2026-10-16:** this result applies to the previous standard BORE-LTO kernel, not the then-untested RT-Bore-LTO kernel.
>
> On 2026-10-16, the project owner reported that GitHub Actions CI was green, the NixOS rebuild and standard BORE-LTO kernel build completed successfully, the Windows VM started, and a normal VM shutdown returned the host display and Hyprland session. At that time, the selected RT-Bore-LTO variant had not yet been built or tested. This is a historical, owner-reported result for the previous kernel and was not independently reproduced during this audit. The later RT-Bore-LTO test is recorded in the 2026-10-23 update below.

### Target-system validation update — 2026-10-23

> The project owner now reports that NixOS rebuilt successfully, the RT-Bore-LTO ThinLTO kernel compiled successfully, the Windows VM started and shut down normally, and control returned to Hyprland. This is owner-reported validation on the target machine, not independent reproduction and not a guarantee for other hardware.

## License

MIT. See [`LICENSE`](LICENSE).

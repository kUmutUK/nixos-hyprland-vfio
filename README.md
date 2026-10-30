# NixOS · Hyprland · AMD GPU Passthrough (VFIO)

A flake-based NixOS gaming desktop that passes its single AMD Radeon GPU through to a Windows 10 virtual machine, while using Hyprland for the host desktop.

The latest follow-up review of canonical ZIP provenance, deployed VM XML validation, VFIO host-driver recovery, and the 2026-10-30 source-tree checks is recorded in the [repair and validation report](docs/REPAIR-AND-VALIDATION-REPORT.md). The 2026-10-28 audit remains a dated historical review.

> **Windows guest lifecycle warning:** The default template targets Windows 10 22H2. Standard support for Windows 10 Home/Pro ended on 14 October 2025. This repository does not enroll the guest in Extended Security Updates (ESU), confirm license eligibility, or verify that guest updates are installed. Before using the VM for network-connected or sensitive activity, check the installed edition and license, verify current ESU or other supported-lifecycle coverage, and install all available security updates. See [Microsoft's end-of-support guidance](https://support.microsoft.com/en-us/windows/windows-10-support-has-ended-on-october-14-2025) and [ESU FAQ](https://learn.microsoft.com/en-us/lifecycle/faq/extended-security-updates). Windows 11 migration is not automated by this repository; do not assume the existing VM XML meets Windows 11 requirements.

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
- [License](#license)

## Purpose and safety

The host is used for gaming and daily desktop work. When the VM starts, the QEMU hook stops the host graphical session and attaches the GPU functions to `vfio-pci`. When the VM stops, the hook attempts to return the GPU to the host drivers and restore the session. A failed preparation step should roll back and prevent the VM from starting.

This is a personal, hardware-specific configuration, not a universal NixOS installer. The included configuration sets `networking.hostName = "nixos"`; change it in `nixos/configuration.nix` if the target host should use a different name. Incorrect disk identifiers can destroy data; incorrect filesystem UUIDs can prevent boot; and a failed single-GPU reset can leave the host without graphics. Back up important data and keep a physical recovery TTY available before testing. SSH password and keyboard-interactive login are disabled by default; add a trusted public key under `users.users.localhost.openssh.authorizedKeys.keys` before relying on SSH. Root login is disabled. TCP 22 is allowed by the host firewall, so also restrict source networks at the router or by adapting the host firewall. The QEMU hook terminates only the local `seat0` sessions so a headless SSH session should survive VM startup. Test remote access before relying on it; the hook will abort and roll back if a process still holds the GPU device nodes.

The repository is MIT-licensed and is provided “as is,” without warranty. Use it at your own risk.

## Requirements

| Component | Target / notes |
|---|---|
| CPU | AMD Ryzen desktop CPU. Intel is not supported by this configuration: `kvm-amd` and `amd_pstate` are AMD-oriented. |
| Desktop environment | Hyprland 0.55 or newer; this configuration uses the native Lua API introduced in [Hyprland 0.55](https://hypr.land/news/update55/). |
| GPU | AMD Radeon RX 6700 XT (Navi 22) is the documented target; its native LLVM target is `gfx1031`. The configured `rocmOverrideGfx = "10.3.0"` selects the `gfx1030` compatibility target, not the card's native identity. This is a compatibility workaround, not proof of official ROCm support; the RX 6700 XT is not listed in AMD's [current Linux ROCm support matrix](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/reference/system-requirements.html). Do not copy this override to another GPU. |
| Firmware | UEFI. Enable IOMMU / AMD-Vi in firmware and verify it after boot with `dmesg` and `/sys/kernel/iommu_groups/`. |
| Storage | The reference partitions total 809 GiB: 1 GiB EFI, 8 GiB swap, and an 800 GiB LUKS2/Btrfs volume. Use a disk of at least 810 GiB (about 870 GB decimal); a 1 TB-class disk is recommended. |
| Host memory | 32 GiB is recommended with the template's default 16 GiB guest allocation; on smaller systems, reduce guest memory or limit concurrent host workloads. This is a recommendation, not a hard minimum. |
| Guest memory | The Windows template assigns 16 GiB (16,777,216 KiB) to the VM; reserve additional memory for NixOS, Hyprland, and host applications. |
| Guest CPU | The template assigns 6 vCPUs as six guest cores. Keep sufficient CPU capacity for the NixOS host; these vCPUs are not exclusive or pinned physical cores. |
| VM devices | The template includes an ICH9 emulated sound device, but it has no host audio backend because `audio type="none"` is configured; use the passed-through GPU HDMI/DP audio function for guest output when available. It also includes an e1000e emulated network adapter (Windows 10 has an inbox driver; no VirtIO network driver is needed) and an iTCO watchdog with reset action. Review these defaults before defining a new VM; preserve an existing VM definition rather than replacing it with the template. |
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
SOURCE_REVISION="$(git -C /tmp/repo rev-parse --verify HEAD)"
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
# Pin post-reboot VM tooling to the checkout used for this installation.
printf '%s\n' "$SOURCE_REVISION" | sudo tee /mnt/etc/nixos/.source-revision >/dev/null
sudo chmod 0644 /mnt/etc/nixos/.source-revision

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
- The clean-install commands record the original Git commit in `/mnt/etc/nixos/.source-revision`. After reboot, VM preparation checks out and verifies that exact revision and stops if the checkout is dirty or different, preventing VM scripts/XML from drifting away from the installed configuration.
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

5. After reviewing that diff and the values above, copy all five required Nix/flake files. This overwrites their corresponding target files, so do not run it before making and checking the backup:

```bash
set -Eeuo pipefail
REPO="$HOME/nixos-hyprland-vfio"   # same checkout path as above
SOURCE_REVISION="$(git -C "$REPO" rev-parse --verify 'HEAD^{commit}')"
if [[ ! "$SOURCE_REVISION" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: Could not resolve a valid source commit from $REPO." >&2
  exit 1
fi
if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=all)" ]; then
  echo "ERROR: $REPO has local or untracked changes. Use a clean checkout before migrating." >&2
  exit 1
fi
sudo install -d -m 0755 /etc/nixos/nixos
for file in configuration.nix home.nix flake.nix flake.lock lsfg-vk-v2.nix; do
  sudo install -m 0644 "$REPO/nixos/$file" /etc/nixos/nixos/
done
sudo install -d -m 0755 /etc/nixos/nixos/hooks
sudo install -m 0755 "$REPO/nixos/hooks/qemu" /etc/nixos/nixos/hooks/qemu
printf '%s\n' "$SOURCE_REVISION" | sudo tee /etc/nixos/.source-revision >/dev/null
sudo chmod 0644 /etc/nixos/.source-revision
```

6. **Preserve machine-specific settings.** If `/etc/nixos/nixos/hardware-configuration.nix` does not exist, first verify that `/etc/nixos/hardware-configuration.nix` was generated on this machine, then copy it (never use the repository template as a substitute):

```bash
if [ ! -f /etc/nixos/nixos/hardware-configuration.nix ]; then
  test -f /etc/nixos/hardware-configuration.nix || { echo "No machine-generated hardware-configuration.nix; stop and generate/review one first." >&2; exit 1; }
  sudo install -m 0644 /etc/nixos/hardware-configuration.nix /etc/nixos/nixos/hardware-configuration.nix
fi
```

**Preserve machine-specific settings.** Never copy `REPO/nixos/hardware-configuration.nix` just because the file exists in the repository. Use the file generated on this machine. If `/etc/nixos/nixos/hardware-configuration.nix` already exists, compare its UUIDs, mount points, and swap device with the generated `/etc/nixos/hardware-configuration.nix` and merge deliberately; do not blindly replace either. Edit `/etc/nixos/nixos/configuration.nix` and `/etc/nixos/nixos/home.nix` to preserve the previous `system.stateVersion` and `home.stateVersion` values, then review the `home.nix` values listed in [`INSTALLATION.md`](INSTALLATION.md) (`gitName`, `gitEmail`, monitor output, monitor rule, and wallpaper path).

**Mandatory Home Snapper preflight — stop before build/switch if any check fails.**

The shipped `configuration.nix` enables Home Snapper for `/home`. Its matching machine-specific hardware configuration must mount a real Btrfs child subvolume `@home/.snapshots` at `/home/.snapshots`, using the same Btrfs device/UUID as `/home` and `neededForBoot = true`. Do not copy the repository's sample UUIDs. Run this check after choosing/merging the target hardware configuration and before the build or activation:

```bash
set -Eeuo pipefail
TARGET_HW=/etc/nixos/nixos/hardware-configuration.nix
if [[ ! -s "$TARGET_HW" ]]; then
  echo "ERROR: Missing machine-specific hardware configuration: $TARGET_HW" >&2
  exit 1
fi

if ! HOME_FSTYPE="$(findmnt -rn -o FSTYPE --target /home)"; then
  echo "ERROR: Cannot determine the filesystem covering /home." >&2
  exit 1
fi
if [[ "$HOME_FSTYPE" != "btrfs" ]]; then
  echo "ERROR: Home Snapper requires Btrfs /home; found $HOME_FSTYPE." >&2
  exit 1
fi

if ! HOME_INFO="$(LC_ALL=C sudo btrfs subvolume show /home)"; then
  echo "ERROR: Cannot verify /home as a Btrfs subvolume." >&2
  exit 1
fi
HOME_NAME="$(awk -F: '/^Name:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' <<< "$HOME_INFO")"
if [[ "$HOME_NAME" != "@home" ]]; then
  echo "ERROR: Expected /home to be the @home subvolume; found '$HOME_NAME'." >&2
  echo "Adapt the configuration to the actual layout; do not activate it blindly." >&2
  exit 1
fi

if ! SNAPSHOT_INFO="$(LC_ALL=C sudo btrfs subvolume show /home/.snapshots 2>/dev/null)"; then
  if sudo test -e /home/.snapshots || sudo test -L /home/.snapshots; then
    echo "ERROR: /home/.snapshots exists but is not verified as a Btrfs subvolume." >&2
    echo "Inspect its contents and mount state manually; do not delete or convert it automatically." >&2
  else
    echo "ERROR: Required Btrfs subvolume /home/.snapshots is missing." >&2
    echo "Only after confirming /home is the correct @home subvolume and this path is absent, create it with:" >&2
    echo "  sudo btrfs subvolume create /home/.snapshots" >&2
    echo "Then rerun this preflight." >&2
  fi
  exit 1
fi
SNAPSHOT_NAME="$(awk -F: '/^Name:/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' <<< "$SNAPSHOT_INFO")"
if [[ "$SNAPSHOT_NAME" != ".snapshots" && "$SNAPSHOT_NAME" != "@home/.snapshots" ]]; then
  echo "ERROR: /home/.snapshots resolves to subvolume '$SNAPSHOT_NAME', not the expected @home/.snapshots child." >&2
  echo "Do not use the root @snapshots subvolume here; inspect and correct the layout manually." >&2
  exit 1
fi

HOME_BLOCK="$(awk '
  /fileSystems\."\/home"[[:space:]]*=/ { capture=1 }
  capture { print }
  capture && /^[[:space:]]*};[[:space:]]*$/ { exit }
' "$TARGET_HW")"
SNAPSHOT_BLOCK="$(awk '
  /fileSystems\."\/home\/\.snapshots"[[:space:]]*=/ { capture=1 }
  capture { print }
  capture && /^[[:space:]]*};[[:space:]]*$/ { exit }
' "$TARGET_HW")"
if [[ -z "$HOME_BLOCK" || -z "$SNAPSHOT_BLOCK" ]]; then
  echo "ERROR: Target hardware configuration must define both /home and /home/.snapshots mounts." >&2
  exit 1
fi
if ! grep -Fq 'fsType = "btrfs";' <<< "$HOME_BLOCK"; then
  echo "ERROR: The /home mount must use Btrfs." >&2
  exit 1
fi
if ! grep -Fq '"subvol=@home"' <<< "$HOME_BLOCK"; then
  echo "ERROR: The /home mount must use subvol=@home for this configuration." >&2
  exit 1
fi
if ! grep -Fq 'fsType = "btrfs";' <<< "$SNAPSHOT_BLOCK"; then
  echo "ERROR: The /home/.snapshots mount must use Btrfs." >&2
  exit 1
fi
if ! grep -Fq '"subvol=@home/.snapshots"' <<< "$SNAPSHOT_BLOCK"; then
  echo "ERROR: The /home/.snapshots mount must use subvol=@home/.snapshots." >&2
  exit 1
fi
if ! grep -Fq 'neededForBoot = true;' <<< "$SNAPSHOT_BLOCK"; then
  echo "ERROR: The /home/.snapshots mount must include neededForBoot = true." >&2
  exit 1
fi
HOME_DEVICE="$(sed -n 's/^[[:space:]]*device[[:space:]]*=[[:space:]]*\(.*\);[[:space:]]*$/\1/p' <<< "$HOME_BLOCK" | head -n 1)"
SNAPSHOT_DEVICE="$(sed -n 's/^[[:space:]]*device[[:space:]]*=[[:space:]]*\(.*\);[[:space:]]*$/\1/p' <<< "$SNAPSHOT_BLOCK" | head -n 1)"
if [[ -z "$HOME_DEVICE" || "$HOME_DEVICE" != "$SNAPSHOT_DEVICE" ]]; then
  echo "ERROR: /home and /home/.snapshots must resolve to the same Btrfs device/UUID." >&2
  echo "Review both device entries and the rootDev definition before continuing." >&2
  exit 1
fi

printf 'Verified /home filesystem: %s\n' "$HOME_FSTYPE"
printf 'Current /home source and options (compare with the target device/UUID):\n'
findmnt -rn -o SOURCE,OPTIONS --target /home
printf 'Filesystem UUID inventory for manual comparison with the target device entry:\n'
lsblk -f
printf 'Verified /home subvolume: %s; child snapshot subvolume: %s\n' "$HOME_NAME" "$SNAPSHOT_NAME"
printf 'Target /home mount:\n%s\nTarget /home/.snapshots mount:\n%s\n' "$HOME_BLOCK" "$SNAPSHOT_BLOCK"
echo "Home Snapper preflight passed. Compare the displayed mounted source, lsblk filesystem UUIDs, and both target device entries before building."
```

If any test fails, stop. Do not run `nixos-rebuild build`, `dry-activate`, or `switch` until the Btrfs layout and target mount declaration have been corrected and this check passes. If the hardware file uses a different subvolume layout, adapt the mount declarations to the actual machine rather than copying the example literally.

7. Find the GPU display and HDMI/DP audio functions with `lspci -Dnn`. Edit `/etc/nixos/nixos/hooks/qemu` so `GPU_PCI` and `GPU_AUDIO` match the actual PCI addresses. Validate IOMMU groups and make sure no unrelated device shares an unsafe group before using passthrough.

8. For an existing VM, **do not replace its XML with the repository template**. Preserve its UUID, MAC, firmware/NVRAM and primary Windows disk path. When `win10` is already registered with libvirt, the `scripts/sync-vm-xml.py --domain win10` helper uses the persistent definition from `virsh dumpxml --inactive win10`; it fails closed if libvirt cannot be queried and backs up both the registered definition and any existing on-disk XML before synchronizing only the two GPU/audio PCI addresses. For a new VM, use the helper in [Preparing and starting the VM](#preparing-and-starting-the-vm) instead of copying the template directly; it generates a fresh UUID and MAC and leaves the source template unchanged. Review the disk/ISO paths and USB IDs before defining the XML. Before any manual production-XML definition, run `sudo python3 "$REPO/scripts/check-vm-iso-paths.py" /var/lib/libvirt/win10.xml`; define the XML with `sudo virsh define /var/lib/libvirt/win10.xml` only after the preflight passes and the guest is shut down. This checker validates file-backed CD-ROM sources only; separately verify the primary qcow2 disk, NVRAM/firmware paths, permissions, and available storage.

9. Check the password file, run these **minimum pre-switch regression checks**, and build before switching. This is not the complete CI-equivalent validation suite; see [Validation](#validation) for the full repository checks.

```bash
bash -n "$REPO/install.sh"
bash "$REPO/scripts/test-installer-invariants.sh"
bash "$REPO/scripts/test-installer-rollback.sh"
bash "$REPO/scripts/test-vfio-hook-driver-state.sh"
python3 "$REPO/scripts/test-lsfg-vk-v2.py"
python3 "$REPO/scripts/test-extract-embedded-scripts.py"
python3 "$REPO/scripts/test-vm-iso-paths.py"
python3 "$REPO/scripts/test-vm-xml.py"
python3 "$REPO/scripts/test-vm-xml-structure.py"
python3 "$REPO/scripts/test-vm-xml-paths.py"
python3 "$REPO/scripts/test-vm-xml-sync.py"
python3 "$REPO/scripts/test-vm-diagnostic.py"
sudo nixos-rebuild build --flake /etc/nixos/nixos#nixos
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

Only after reviewing the build and dry-activation output should you run `sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos`. Keep the backup and a working recovery generation until you have verified boot, graphics login, SSH access, and the complete VM start/shutdown/display-recovery cycle.

### Path C — Optional `install.sh` migration helper (advanced users only; not the default recommendation)

Use this only if you have reviewed the script and intentionally prefer its automated migration flow over the manual steps above. It is **not** a fresh-installer or disk-partitioning tool. It replaces source files under `/etc/nixos/nixos` (including `/etc/nixos/nixos/hooks/qemu`) and writes `/var/lib/libvirt/win10.xml`; it does **not** directly replace the currently active libvirt hook or automatically define the updated VM XML. The active hook is generated from `nixos/configuration.nix` and is refreshed only after a successful NixOS rebuild/activation. When `win10` is registered with libvirt, the helper prefers the persistent `virsh dumpxml --inactive win10` definition over a missing or stale `/var/lib/libvirt/win10.xml`; libvirt query/export failures stop the migration before writes. The registered XML and any existing on-disk XML are backed up before changing only the two PCI hostdev source addresses. When the domain is not registered, an existing deployed XML remains the source of truth; only a genuinely new, unregistered VM starts from the reviewed template. If the existing XML is malformed, belongs to another domain, has an unsupported primary-disk layout, or does not contain exactly two synchronizable PCI hostdevs, the helper aborts so you can use the manual path. On a new VM, it starts from the repository template. Incorrect PCI addresses, state versions, or mount settings can still make the host or VM unusable. Backup/rollback remains best-effort and does not replace a full backup or a tested recovery method. The script does not automatically rebuild/activate the host, define the VM XML, or reboot, and it retains prior installer backups without automatically deleting them. Do not run it as root; keep its repository checkout outside `/etc/nixos`.

```bash
# Review the whole script and the manual migration section first.
less install.sh
bash -n install.sh
./install.sh
```

The installer displays a risk notice and requires the exact acknowledgement phrase shown by the script. It takes a non-blocking per-user process lock before prompting, backing up, or deploying; another `install.sh` process for the same user exits rather than overlapping the transaction. This lock does not coordinate separately configured lock paths or different user accounts, so run the migration from one account at a time. The NixOS and live-ISO guards run before the acknowledgement prompt. After acknowledgement, the installer requires working `virsh`/libvirt access and verifies that a registered `win10` domain reports exactly `shut off`; inability to query the state or any other state aborts the migration. It repeats this check immediately before creating the first backup, narrowing the race window if another process starts the VM during interactive setup. It also requires `/home` to be backed by Btrfs because the shipped configuration enables Home Snapper; this is checked before backups or managed system changes. For a non-Btrfs `/home`, use the manual migration path and explicitly adapt the Home Snapper configuration and any `/home/.snapshots` mount before deploying. The installer also preflights IOMMU-group availability for the selected GPU functions; enable AMD-Vi/IOMMU in firmware and verify the groups before continuing. It does not add `amd_iommu=on` or `iommu=pt` kernel parameters. If you do not fully understand or accept the changes, cancel and use Path B.

Maintainers creating a source ZIP should use the repository packaging helper. It packages the committed `HEAD` (not uncommitted working-tree edits), verifies that every tracked file is present, rejects `.git` metadata, and checks the Unix executable bits of all tracked executable files before publishing the ZIP. Do not create a delivery ZIP by compressing the checkout folder in a file manager; that can include private/local Git metadata and lose the `install.sh` executable bit. CI runs the same helper and uploads its validated output as the `nixos-hyprland-vfio-source` workflow artifact.

```bash
scripts/package-source-zip.sh "$PWD/nixos-hyprland-vfio.zip"
```

### Activate and reboot

Before rebuilding, make sure `/etc/nixos/hashedPassword` exists and contains a
valid password hash. `localhost` uses this file via `hashedPasswordFile`; if it is
missing, the account can remain locked and Hyprland login will fail. This is the
local account's password hash and **does not enable SSH password authentication**:
SSH password and keyboard-interactive login remain disabled. Add a trusted public
key under `users.users.localhost.openssh.authorizedKeys.keys` before relying on
remote SSH access. Preserve an existing valid hash. Only create a new one if the
file is missing or empty:

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

OpenSSH is enabled on TCP port 22 and the host firewall allows that port, but password and keyboard-interactive authentication are disabled by default. No public key is shipped: add your own key to `users.users.localhost.openssh.authorizedKeys.keys` before relying on SSH, then test login from a second device and a fresh session. `AllowUsers = [ "localhost" ]` restricts the login name, not the source IP or listening interface; restrict port 22 at the network edge or add a host-firewall allow-list before exposing it to untrusted networks. Root login is disabled, public-key authentication is enabled, and Fail2ban remains active as defence in depth. The QEMU hook terminates only local `seat0` sessions, not all sessions for the user, so a headless SSH session should remain connected during GPU handoff. Keep a physical recovery TTY available and test this on your host before relying on it. Connect from another trusted device with `ssh localhost@<host-ip>` (find the address with `ip -br address`).

## Preparing and starting the VM

The VM domain is named `win10`. The default `vm-xml/win10.xml` expects these files under `/var/lib/libvirt/images/`: `Win10_22H2_English_x64v1.iso`, `virtio-win-0.1.285.iso`, and `win10new.qcow2`. Confirm that the ISO files you downloaded match the XML paths; edit the XML if their names or locations differ. The XML uses the SATA bus for both CD-ROM drives; the operating-system disk uses VirtIO and needs the VirtIO storage driver during Windows setup. The structural XML test does not depend on ISO filenames: it requires two distinct, absolute file-backed CD-ROM paths with explicit boot priorities, and treats the earlier optical boot entry (after the system disk) as the Windows installer and the later one as the VirtIO driver ISO. This checks the declared XML structure, not the actual contents of the ISO files; `scripts/check-vm-iso-paths.py` separately checks that the paths exist.

> **Windows 10 lifecycle:** Standard support for Windows 10 Home and Pro ended on October 14, 2025 ([Microsoft lifecycle policy](https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro)). Eligible, enrolled consumer devices may receive ESU protection through October 12, 2027; commercial ESU has separate licensing and coverage dates ([Microsoft ESU FAQ](https://learn.microsoft.com/en-us/lifecycle/faq/extended-security-updates)). This template does not enroll the guest, verify the license/edition, or install updates. Confirm the actual guest's ESU or other supported-lifecycle status before using it online; the ISO filename alone proves none of these conditions.

> **USB passthrough preflight:** The default VM XML contains the machine-specific USB IDs `1532:0098` and `05ac:024f`. Check both on the target host before defining or starting the VM:
>
> ```bash
> lsusb -d 1532:0098
> lsusb -d 05ac:024f
> ```
>
> Both commands must identify the intended connected devices. If either ID is absent or identifies the wrong device, edit or remove its matching USB `<hostdev>` block in `vm-xml/win10.xml`; do not assume these IDs exist on another computer.

After the first system activation and reboot, prepare the VM disk and define the domain. The `/tmp/repo` checkout used in Path A exists only in the Live ISO and is not available after reboot. The block below creates a persistent checkout at `~/nixos-hyprland-vfio` if one does not already exist; change `REPO` if your checkout lives elsewhere. Run it after reviewing the XML disk/ISO paths and USB passthrough IDs. Enter the exact `GPU_PCI` and `GPU_AUDIO` values from the deployed hook at `/etc/nixos/nixos/hooks/qemu`:

```bash
set -euo pipefail
REPO="$HOME/nixos-hyprland-vfio"  # change this if your persistent checkout is elsewhere
SOURCE_REVISION_FILE=/etc/nixos/.source-revision
if [[ ! -f "$SOURCE_REVISION_FILE" || ! -s "$SOURCE_REVISION_FILE" ]]; then
  echo "ERROR: Required source revision record is missing or empty: $SOURCE_REVISION_FILE." >&2
  echo "Use the documented migration path to record the actual source commit; do not infer it from current main." >&2
  exit 1
fi
SOURCE_REVISION="$(tr -d '[:space:]' < "$SOURCE_REVISION_FILE")"
if [[ ! "$SOURCE_REVISION" =~ ^[0-9a-f]{40}$ ]]; then
  echo "ERROR: Invalid source revision in $SOURCE_REVISION_FILE; inspect it before continuing." >&2
  exit 1
fi
if ! git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -e "$REPO" ] || [ -L "$REPO" ]; then
    echo "ERROR: $REPO exists but is not a Git checkout; inspect it before continuing." >&2
    exit 1
  fi
  git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git "$REPO"
  git -C "$REPO" checkout --detach "$SOURCE_REVISION"
fi
bash "$REPO/scripts/verify-source-revision.sh" "$SOURCE_REVISION_FILE" "$REPO"
cd "$REPO"
VM_XML=/var/lib/libvirt/win10.xml
test -f "$REPO/scripts/sync-vm-xml.py"
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu

# Query libvirt itself before treating this as a new VM. With set -e, a failed
# query aborts instead of mistaking an unavailable daemon for an absent domain.
REGISTERED_DOMAINS="$(sudo virsh list --all --name)"
if printf '%s\n' "$REGISTERED_DOMAINS" | grep -Fxq win10; then
  EXISTING_VM_XML=1
elif sudo test -e "$VM_XML" || sudo test -L "$VM_XML"; then
  EXISTING_VM_XML=1
else
  EXISTING_VM_XML=0
fi

STAGING_XML_DIR=
STAGING_DISK_DIR=
STAGED_DISK_PATH=
PUBLISHED_DISK_PATH=
PUBLISHED_DISK_ID=
PUBLISHED_XML_ID=
PUBLISHED_PAIR=0
cleanup_vm_bootstrap() {
  # Two final paths cannot be published as one atomic filesystem operation. If XML
  # publication loses a race, remove only this run's disk inode and preserve the
  # other process's XML/disk. Compare inode identities before rollback.
  if [ "$PUBLISHED_PAIR" -eq 0 ] && [ -n "$PUBLISHED_DISK_PATH" ] && [ -n "$PUBLISHED_DISK_ID" ] && [ -n "$PUBLISHED_XML_ID" ]; then
    CURRENT_XML_ID="$(sudo stat -c '%d:%i' -- "$VM_XML" 2>/dev/null || true)"
    if [ "$CURRENT_XML_ID" != "$PUBLISHED_XML_ID" ]; then
      CURRENT_DISK_ID="$(sudo stat -c '%d:%i' -- "$PUBLISHED_DISK_PATH" 2>/dev/null || true)"
      if [ "$CURRENT_DISK_ID" = "$PUBLISHED_DISK_ID" ]; then
        sudo rm -- "$PUBLISHED_DISK_PATH" || true
      fi
    fi
  fi
  if [ -n "$STAGING_XML_DIR" ]; then sudo rm -rf -- "$STAGING_XML_DIR" || true; fi
  if [ -n "$STAGING_DISK_DIR" ]; then sudo rm -rf -- "$STAGING_DISK_DIR" || true; fi
}
trap cleanup_vm_bootstrap EXIT

# Existing VMs use their deployed XML directly. New VMs use disposable staging
# locations so a failed ISO/disk preflight cannot leave a false "existing VM".
BOOTSTRAP_XML="$VM_XML"
if [ "$EXISTING_VM_XML" -eq 0 ]; then
  STAGING_XML_DIR="$(sudo mktemp -d /var/lib/libvirt/.win10-bootstrap.XXXXXX)"
  STAGING_DISK_DIR="$(sudo mktemp -d /var/lib/libvirt/images/.win10-bootstrap.XXXXXX)"
  BOOTSTRAP_XML="$STAGING_XML_DIR/win10.xml"
  STAGED_DISK_PATH="$STAGING_DISK_DIR/win10new.qcow2"
fi

read -rp "GPU display PCI address from /etc/nixos/nixos/hooks/qemu: " GPU_PCI
read -rp "GPU audio PCI address from /etc/nixos/nixos/hooks/qemu: " GPU_AUDIO
sudo python3 "$REPO/scripts/sync-vm-xml.py" \
  "$GPU_PCI" "$GPU_AUDIO" \
  "$REPO/vm-xml/win10.xml" "$BOOTSTRAP_XML" --domain win10

# Fail before creating a VM disk if any file-backed CD-ROM source is missing.
sudo python3 "$REPO/scripts/check-vm-iso-paths.py" "$BOOTSTRAP_XML"

# Read the primary disk path from the synchronized XML; do not assume a filename.
DISK_PATH="$(sudo python3 - "$BOOTSTRAP_XML" <<'PY'
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
echo "Primary disk path in $BOOTSTRAP_XML: $DISK_PATH"

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
  # Keep partial image creation and metadata failures inside the disposable staging directory.
  sudo qemu-img create -f qcow2 "$STAGED_DISK_PATH" 120G
  sudo chown qemu-libvirtd:qemu-libvirtd "$STAGED_DISK_PATH"
  sudo chmod 0660 "$STAGED_DISK_PATH"

  # Publish without replacing paths created concurrently by another process.
  if sudo test -e "$VM_XML" || sudo test -L "$VM_XML"; then
    echo "ERROR: $VM_XML appeared during new-VM preparation; refusing to overwrite it." >&2
    exit 1
  fi
  PUBLISHED_XML_ID="$(sudo stat -c '%d:%i' -- "$BOOTSTRAP_XML")"
  PUBLISHED_DISK_ID="$(sudo stat -c '%d:%i' -- "$STAGED_DISK_PATH")"
  PUBLISHED_DISK_PATH="$DISK_PATH"
  sudo mv --no-clobber --no-target-directory -- "$STAGED_DISK_PATH" "$DISK_PATH"
  if sudo test -e "$STAGED_DISK_PATH"; then
    echo "ERROR: The VM disk destination changed during preparation; refusing to continue." >&2
    exit 1
  fi
  sudo mv --no-clobber --no-target-directory -- "$BOOTSTRAP_XML" "$VM_XML"
  if sudo test -e "$BOOTSTRAP_XML"; then
    echo "ERROR: The VM XML destination changed during preparation; refusing to overwrite it." >&2
    exit 1
  fi
  PUBLISHED_PAIR=1
fi

# Define only the validated XML at its final path.
sudo virsh define "$VM_XML"
```

When called with --domain win10, the helper checks libvirt itself and prefers the persistent `virsh dumpxml --inactive win10` definition over a missing or stale on-disk XML; if libvirt cannot be queried or the registered domain cannot be exported, it stops without writing. The registered persistent definition and any existing on-disk XML are backed up before the destination changes. If win10 is not registered, an existing deployed XML remains the source of truth; only a genuinely new, unregistered VM starts from the template and receives a fresh UUID/MAC. The helper preserves existing VM settings and changes only the two GPU/audio PCI addresses. It refuses to replace a symlink, malformed XML, a different VM domain, or an unsupported disk/PCI layout. It never edits `vm-xml/win10.xml`. The disk setup above reads the actual primary disk path from the synchronized XML: existing VM disks are preserved and are never auto-created, re-owned, or re-permissioned; a missing disk for an existing VM stops for manual recovery. Automatic creation is limited to the reviewed 120G default path for a new VM. Verify the Windows and VirtIO ISO paths in the deployed XML exist before starting the guest. The XML's PCI addresses must match `GPU_PCI` and `GPU_AUDIO` in `/etc/nixos/nixos/hooks/qemu`; `install.sh` performs this synchronization when run successfully. For a new VM, the manual flow keeps the XML and disk in temporary staging directories until ISO checks and disk creation/ownership/permissions succeed. A missing ISO or staged disk-creation failure therefore leaves no deployed XML or final-path partial disk, and the user can retry safely; concurrent destination conflicts fail closed rather than overwriting files.

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
| `lsfg-vk` | Pinned LSFG-VK v2 Vulkan layer, Qt6 UI, and CLI; per-game v2 profiles are declared in Home Manager `conf.toml` |
| `low_latency_layer` | Vulkan latency layer enabled globally using `LOW_LATENCY_LAYER=1`; keeps the default AMD Anti-Lag interface for native Linux games such as CS2. Compatible Proton games can opt into Reflex with `LOW_LATENCY_LAYER_REFLEX=1 %command%`; incompatible games can use `DISABLE_LOW_LATENCY_LAYER=1 %command%`. |
| GameMode | Applies the configured game-time priority and performance settings |
| Gamescope | Fullscreen and window rules for games |
| MangoHud | FPS, frametime, GPU/CPU, and temperature overlay |
| Ananicy-cpp | Process priority rules |
| power-profiles-daemon | Power profile / CPU governor management |
| Steam / Proton / Wine | Windows game compatibility tools |

**Lossless Scaling prerequisite:** Install Lossless Scaling through Steam on the host. The `lsfg-vk` Nix package provides the Vulkan frame-generation layer; it does not bundle the Lossless Scaling application. If Lossless Scaling is installed in a non-default Steam library, configure the corresponding path in the LSFG-VK configuration.

The upstream Vulkan manifest enables the latency layer through `LOW_LATENCY_LAYER=1` and supports per-game opt-out through `DISABLE_LOW_LATENCY_LAYER=1`. The system keeps the default AMD Anti-Lag interface globally; compatible Proton games can opt into Reflex with `LOW_LATENCY_LAYER_REFLEX=1 %command%`. To disable the layer for one incompatible game, launch it with `DISABLE_LOW_LATENCY_LAYER=1 %command%`. Inspect active layers with:

```bash
VK_LOADER_DEBUG=layer vulkaninfo 2>&1 | grep -iE 'korthos|lsl'
```

**CS2 / Source 2 note:** the upstream [`low_latency_layer` v0.2.0 release notes](https://github.com/Korthos-Software/low_latency_layer/releases/tag/v0.2.0) document frame-pacing issues when an in-engine FPS cap is enabled. While the layer is active, use `fps_max 0` in CS2 until upstream resolves the issue; an external cap such as MangoHud's has been reported not to trigger it. If you still see stutter or frame-pacing problems, opt CS2 out with `DISABLE_LOW_LATENCY_LAYER=1 %command%` and compare frametimes.

## Important configuration decisions

- `systemd-boot` is used; UEFI is required.
- The QEMU hook is installed via `virtualisation.libvirtd.hooks.qemu.vfio`. The path is supplied by NixOS to libvirt's hook mechanism.
- The hook uses an explicit store-path Bash interpreter and controlled `PATH`, since libvirt service environments are minimal.
- `zramSwap.priority = 100` is higher than disk swap priority `10`, so zram is preferred.
- `vm.swappiness = 180` is an intentional aggressive swap tendency, not a priority setting. It can increase major page faults and frametime spikes if disk swap is used.
- `hypridle` requests suspend after 900 seconds; Hyprlock is invoked through the configured pre-sleep command.
- `HYPRLAND_CONFIG` is passed through the greetd wrapper and points to the native Lua config generated from `nixos/home.nix` at `~/.config/hypr/hyprland.lua`.
- `input-remapper` is installed, but this configuration does not enable its background service. Installing the package alone does not apply mappings; enable `services.input-remapper.enable = true` only when you intentionally configure remapping rules.
- `nowatchdog` and `nmi_watchdog=0` reduce watchdog-based lockup diagnostics in exchange for less diagnostic data.
- `usbcore.autosuspend=-1` and `kvm.ignore_msrs=1` are **not enabled by default** in `nixos/configuration.nix`. The former disables USB autosuspend and may increase idle power consumption; the latter suppresses some unknown MSR access failures and can hide guest problems. Add either only when the target hardware/guest needs it and after considering the trade-offs.

## Known limitations

- **RT-Bore-LTO validation:** the upstream source does not publish the ThinLTO variant in its binary cache, so each newly selected upstream revision needs a local build. The project owner reports that the currently locked revision built and passed the VM start/shutdown and Hyprland-recovery check on the target machine (see the 2026-10-23 update below); this result is owner-reported, not independently reproduced, and does not guarantee compatibility on other hardware. Real-time preemption does not guarantee higher FPS or better frametimes. Retain a known-good boot generation when testing future kernel revisions.
- **Global Vulkan latency layer compatibility:** upstream `low_latency_layer` v0.2.0 documents an incompatibility with the `obs_vkcapture` Vulkan capture layer. If game capture or recording breaks while the layer is enabled, launch the affected game with `DISABLE_LOW_LATENCY_LAYER=1 %command%` and verify whether capture works again.
- **LSFG-VK schema:** the current tree uses the upstream v2 `[[profile]]` profile format (`version = 2` and `[global]`). The layer/UI/CLI are built from the immutable revision and source hash in `nixos/lsfg-vk-v2.nix`; CI validates the generated TOML and builds `.#lsfg-vk-v2`. Upstream is licensed CC BY-NC-ND 4.0, so the package does not patch or redistribute modified upstream source. Lossless Scaling itself must be separately installed through Steam.
- **Wuthering Waves LSFG profile:** the v2 configuration includes common Proton/Wine executable aliases `Client-Win64-Shipping.exe` and `Client-Win64-Shipping`. Confirm the actual process name selected by LSFG-VK from the target machine's runtime log; the static configuration test cannot prove the profile is activated in-game.
- **Waydroid and single-GPU VFIO:** the hook records the prior activity of `waydroid-container.service`, stops it during GPU handoff, and restores it only if it was active beforehand. Mock tests cannot prove the target host releases every GPU file descriptor; verify the complete VM lifecycle on the physical target system.
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
├── README.md
├── .gitattributes                  # expand source commit identity in canonical ZIPs
├── SOURCE_REVISION                 # Git archive expands this to the packaged commit
├── .gitignore
├── DISCLAIMER.md
├── KURULUM.md                      # English compatibility pointer to INSTALLATION.md
├── INSTALLATION.md                 # English fresh-install guide
├── DEGISIKLIK_GECMISI.md           # English current-state summary + archive pointer
├── CONTRIBUTING.md
├── CHANGELOG.md
├── LICENSE
├── statix.toml                     # Statix lint configuration
├── install.sh                      # migration/update helper for an existing NixOS host
├── .github/workflows/check.yml
├── .github/workflows/full-system-build.yml
├── docs/
│   ├── REPAIR-AND-VALIDATION-REPORT.md
│   ├── AUDIT-2026-10-28-VM-XML-VFIO.md
│   └── archive/                    # Historical audits and original Turkish release history
├── scripts/
│   ├── check-vm-iso-paths.py
│   ├── extract-embedded-scripts.py
│   ├── package-source-zip.sh
│   ├── check-home-snapper-layout.py
│   ├── test-home-snapper-layout.py
│   ├── verify-source-revision.sh
│   ├── test-source-revision.sh
│   ├── installer-lock.sh
│   ├── pci-address.sh
│   ├── prepare-vm-diagnostic.py
│   ├── test-extract-embedded-scripts.py
│   ├── test-documentation-integrity.py
│   ├── test-lsfg-vk-v2.py
│   ├── test-installer-invariants.sh
│   ├── test-installer-lock.sh
│   ├── test-installer-rollback.sh
│   ├── test-manual-vm-bootstrap.sh
│   ├── test-vfio-hook-driver-state.sh
│   ├── sync-vm-xml.py
│   ├── test-vm-diagnostic.py
│   ├── test-vm-iso-paths.py
│   ├── test-vm-xml-paths.py
│   ├── test-vm-xml-sync.py
│   ├── test-vm-xml-structure.py
│   └── test-vm-xml.py
├── vm-xml/win10.xml
└── nixos/
    ├── flake.nix
    ├── flake.lock
    ├── configuration.nix
    ├── home.nix
    ├── lsfg-vk-v2.nix
    ├── hardware-configuration.nix   # machine-specific: replace for another host
    └── hooks/qemu
```

Hyprland's native Lua configuration, Hyprlock, Waybar, Pyprland, MangoHud, lsfg-vk, and helper scripts are declared inline in `nixos/home.nix`; there is no parallel Hyprland config file to keep in sync.

## Validation

To distribute a source ZIP, first commit the source you intend to ship, then run
`./scripts/package-source-zip.sh ./dist/nixos-hyprland-vfio-source.zip`.
This packages committed `HEAD` (uncommitted edits are deliberately excluded), expands
`SOURCE_REVISION` to that commit, excludes `.git/`, and verifies the tracked-file
inventory and executable permissions. Do not create the distributable by manually
compressing the working directory: that can include Git metadata and leave the revision
placeholder unresolved. CI uploads the validated ZIP as the `nixos-hyprland-vfio-source`
artifact only after the required checks pass. The artifact also contains a relative-path
`nixos-hyprland-vfio-source.zip.sha256` manifest; after downloading both files, verify it
with `sha256sum -c nixos-hyprland-vfio-source.zip.sha256`.

Run from the repository root. The command uses fail-fast behavior, validates Nix formatting without rewriting files, and runs tests inside the development shell.

```bash
nix develop ./nixos --command bash -euo pipefail -c '
  find ./nixos -type f -name "*.nix" -print0 | xargs -0 -r nixfmt --check
  for f in \
    install.sh \
    scripts/package-source-zip.sh \
    scripts/verify-source-revision.sh \
    scripts/test-source-revision.sh \
    scripts/installer-lock.sh \
    scripts/pci-address.sh \
    scripts/test-installer-lock.sh \
    nixos/hooks/qemu \
    scripts/test-vfio-hook-driver-state.sh \
    scripts/test-installer-invariants.sh \
    scripts/test-installer-rollback.sh \
    scripts/test-manual-vm-bootstrap.sh
  do
    bash -n "$f" || exit 1
  done
  shellcheck -S warning install.sh scripts/package-source-zip.sh scripts/verify-source-revision.sh scripts/test-source-revision.sh scripts/installer-lock.sh scripts/pci-address.sh nixos/hooks/qemu scripts/test-vfio-hook-driver-state.sh scripts/test-installer-invariants.sh scripts/test-installer-lock.sh scripts/test-installer-rollback.sh scripts/test-manual-vm-bootstrap.sh
  python3 -c "import xml.etree.ElementTree as ET; ET.parse(\"vm-xml/win10.xml\")"
  python3 scripts/test-lsfg-vk-v2.py
  python3 scripts/test-home-snapper-layout.py
  python3 scripts/test-extract-embedded-scripts.py
  python3 scripts/test-documentation-integrity.py
  python3 scripts/test-vm-iso-paths.py
  bash -n scripts/test-manual-vm-bootstrap.sh
  bash scripts/test-manual-vm-bootstrap.sh
  python3 scripts/test-vm-xml.py
  python3 scripts/test-vm-xml-structure.py
  python3 scripts/test-vm-xml-paths.py
  python3 scripts/test-vm-xml-sync.py
  python3 scripts/test-vm-diagnostic.py
  bash scripts/test-vfio-hook-driver-state.sh
  bash scripts/test-installer-lock.sh
  bash scripts/test-source-revision.sh
  bash scripts/test-installer-invariants.sh
  bash scripts/test-installer-rollback.sh
  tmpdir="$(mktemp -d)"
  trap "rm -rf -- \"$tmpdir\"" EXIT
  python3 scripts/extract-embedded-scripts.py "$tmpdir" > "$tmpdir/paths.nul"
  mapfile -d "" -t embedded_scripts < "$tmpdir/paths.nul"
  if [ "${#embedded_scripts[@]}" -ne 7 ]; then
    printf "Expected 7 embedded Bash scripts, found %s\\n" "${#embedded_scripts[@]}" >&2
    exit 1
  fi
  shellcheck -S warning "${embedded_scripts[@]}"
  (cd nixos && nix flake check --no-build --show-trace --no-update-lock-file --option warn-dirty false)
  (cd nixos && nix build --no-link --no-update-lock-file .#lsfg-vk-v2)
  statix check .
  deadnix .
'
```
`nix flake check --no-build` evaluates the flake but does not build the complete system or kernel. The separate `nix build .#lsfg-vk-v2` command builds only the selected LSFG-VK v2 package. Neither command replaces a full system/kernel build, libvirt domain validation, or a physical GPU lifecycle test. To intentionally rewrite formatting, run `nixfmt` without `--check` as a separate reviewed edit.

The manual sequence also runs `statix check .` and `deadnix .`, both required CI gates. `statix.toml` disables only the style-only repeated-key lint used by the repository's intentionally flat option assignments; actionable Statix and Deadnix findings still fail validation.

For a complete NixOS system build on GitHub Actions, open **Actions → Full NixOS System Build (manual) → Run workflow**. This six-hour, manually dispatched job builds `nixosConfigurations.nixos.config.system.build.toplevel`, including the selected RT-Bore-LTO kernel. It is kept out of normal push/PR CI because the custom kernel can be expensive to compile. A successful build validates the build graph on the runner; it does not prove GPU passthrough or host-display recovery on physical hardware.

### Prior target-system hardware validation — 2026-10-16

> **Historical scope as of 2026-10-16:** this result applies to the previous standard BORE-LTO kernel, not the then-untested RT-Bore-LTO kernel.
>
> On 2026-10-16, the project owner reported that GitHub Actions CI was green, the NixOS rebuild and standard BORE-LTO kernel build completed successfully, the Windows VM started, and a normal VM shutdown returned the host display and Hyprland session. At that time, the selected RT-Bore-LTO variant had not yet been built or tested. This is a historical, owner-reported result for the previous kernel and was not independently reproduced during this audit. The later RT-Bore-LTO test is recorded in the 2026-10-23 update below.

### Target-system validation update — 2026-10-23

> The project owner now reports that NixOS rebuilt successfully, the RT-Bore-LTO ThinLTO kernel compiled successfully, the Windows VM started and shut down normally, and control returned to Hyprland. This is owner-reported validation on the target machine, not independent reproduction and not a guarantee for other hardware.

## License

MIT. See [`LICENSE`](LICENSE).

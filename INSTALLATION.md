# NixOS Hyprland + VFIO Installation Guide

Legacy filename: [KURULUM.md](KURULUM.md) (English pointer to this guide)

This guide walks through an AMD-oriented **NixOS + LUKS2 + Btrfs + Hyprland + VFIO** installation.

> **Recommended approach: install manually.** This guide is for a clean installation. Follow the steps in order and understand each command before running it. `install.sh` is not a clean installer or disk-partitioning tool; it is an optional, higher-risk helper for advanced users migrating an existing NixOS system. Read [`README.md`](README.md) for its risk notice and the alternative manual migration steps.

---

# ⚙️ Prerequisites

- NixOS 26.05 Live ISO
- UEFI system
- AMD Ryzen CPU
- AMD Radeon RX 6700 XT (Navi 22) — the reference GPU for this configuration. Other RX 6000/7000 cards are not considered supported until PCI/IOMMU groups, GPU reset behavior, and ROCm settings have been verified separately.
- At least 810 GiB of storage (about 870 GB decimal); a 1 TB-class drive is recommended in practice.

---

# 🚀 1. Live environment

Boot the ISO in UEFI mode

```bash
nmtui
```
Set the keyboard layout to Turkish:

```bash
sudo loadkeys trq
```
---

# 💾 2. Disk partitioning

> ⚠️ **The commands below completely erase the disk's partition table.**
> Selecting the wrong device can destroy your existing system.
> First inspect the attached drives and verify the target drive's model and serial number:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
```
> Check the target drive twice. Replace `/dev/nvme0n1` below with your own
> drive and run the following commands in the same terminal session.

```bash
set -Eeuo pipefail
DISK=/dev/nvme0n1    # CHANGE THIS

# Accept only a whole disk; reject partitions and nonexistent paths.
if [ ! -b "$DISK" ]; then
  echo "ERROR: $DISK is not an existing block device." >&2
  exit 1
fi
DISK_TYPE=$(lsblk -dnro TYPE "$DISK") || exit 1
if [ "$DISK_TYPE" != "disk" ]; then
  echo "ERROR: $DISK is not a disk device (type: $DISK_TYPE)." >&2
  exit 1
fi

DISK_REAL=$(readlink -f -- "$DISK") || {
  echo "ERROR: Could not resolve the target disk canonical device path." >&2
  exit 1
}
DISK_MODEL=$(lsblk -dnro MODEL "$DISK" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
DISK_SERIAL=$(lsblk -dnro SERIAL "$DISK" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
DISK_BYTES=$(sudo blockdev --getsize64 "$DISK") || {
  echo "ERROR: Could not read disk capacity." >&2
  exit 1
}
printf '\nSelected disk:\n  Device: %s\n  Model: %s\n  Serial: %s\n  Size: %s bytes\n' \
  "$DISK_REAL" "${DISK_MODEL:-unknown}" "${DISK_SERIAL:-unknown}" "$DISK_BYTES"

# These functions are called again in later code blocks. Stop if the disk path/model/serial
# number/size changes or the disk is mounted, active as swap, or held by another device.
assert_disk_identity() {
  local real model serial bytes type
  [ -b "$DISK" ] || { echo "ERROR: $DISK is no longer a block device." >&2; return 1; }
  real=$(readlink -f -- "$DISK") || return 1
  type=$(lsblk -dnro TYPE "$DISK") || return 1
  model=$(lsblk -dnro MODEL "$DISK" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  serial=$(lsblk -dnro SERIAL "$DISK" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  bytes=$(sudo blockdev --getsize64 "$DISK") || return 1
  if [ "$real" != "$DISK_REAL" ] || [ "$type" != "disk" ] || \
     [ "$model" != "$DISK_MODEL" ] || [ "$serial" != "$DISK_SERIAL" ] || \
     [ "$bytes" != "$DISK_BYTES" ]; then
    echo "ERROR: Disk identity differs from the initial check; do not continue with destructive operations." >&2
    return 1
  fi
}

assert_disk_unused() {
  local mountpoints active_swaps swap_dev backing_devices backing_dev backing_real
  local device holders_dir holder
  assert_disk_identity || return 1
  mountpoints=$(lsblk -nrpo MOUNTPOINTS "$DISK") || return 1
  if [[ "$mountpoints" =~ [^[:space:]] ]]; then
    echo "ERROR: $DISK or one of its partitions is mounted; refusing to erase it." >&2
    return 1
  fi
  active_swaps=$(sudo swapon --noheadings --raw --show=NAME) || {
    echo "ERROR: Could not verify active swap devices." >&2; return 1;
  }
  while IFS= read -r swap_dev; do
    [ -n "$swap_dev" ] || continue
    [ -b "$swap_dev" ] || continue
    backing_devices=$(lsblk --inverse --noheadings --raw --paths --output NAME "$swap_dev") || return 1
    while IFS= read -r backing_dev; do
      [ -n "$backing_dev" ] || continue
      backing_real=$(readlink -f -- "$backing_dev") || return 1
      if [ "$backing_real" = "$DISK_REAL" ]; then
        echo "ERROR: Active swap ($swap_dev) is on the target disk; operation cancelled." >&2
        return 1
      fi
    done <<< "$backing_devices"
  done <<< "$active_swaps"
  local device_list
  device_list=$(lsblk -nrpo NAME "$DISK") || return 1
  while IFS= read -r device; do
    [ -n "$device" ] || continue
    holders_dir="/sys/class/block/${device##*/}/holders"
    [ -d "$holders_dir" ] || continue
    holder=$(find "$holders_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) || return 1
    if [ -n "$holder" ]; then
      echo "ERROR: $device is in use by an active device ($(basename "$holder")); operation cancelled." >&2
      return 1
    fi
  done <<< "$device_list"
}

assert_disk_unused || exit 1

# G in sgdisk is GiB. The partitions allocate 809 GiB in total.
MIN_DISK_BYTES=$((810 * 1024 * 1024 * 1024))
if [ "$DISK_BYTES" -lt "$MIN_DISK_BYTES" ]; then
  printf 'ERROR: Disk capacity is insufficient (%s bytes); at least 810 GiB (%s bytes) is required.\n' \
    "$DISK_BYTES" "$MIN_DISK_BYTES" >&2
  exit 1
fi
printf 'Capacity check passed: at least 810 GiB. Verify the model and serial number yourself above.\n'

# NVMe partition names use p1/p2; SATA/SCSI partition names use sda1/sda2.
case "$DISK_REAL" in
  *[0-9]) PART_PREFIX="${DISK_REAL}p" ;;
  *)      PART_PREFIX="$DISK_REAL" ;;
esac

assert_partition_on_target() {
  local part="$1" type parent parent_real mountpoints
  [ -b "$part" ] || { echo "ERROR: Expected partition device was not found: $part" >&2; return 1; }
  type=$(lsblk -dnro TYPE "$part") || return 1
  [ "$type" = "part" ] || { echo "ERROR: $part is not a partition (type: $type)." >&2; return 1; }
  parent=$(lsblk -dnro PKNAME "$part") || return 1
  [ -n "$parent" ] || { echo "ERROR: No parent-disk information is available for $part." >&2; return 1; }
  parent_real=$(readlink -f -- "/dev/$parent") || return 1
  [ "$parent_real" = "$DISK_REAL" ] || {
    echo "ERROR: $part does not belong to the selected target disk." >&2; return 1;
  }
  mountpoints=$(lsblk -nrpo MOUNTPOINTS "$part") || return 1
  if [[ "$mountpoints" =~ [^[:space:]] ]]; then
    echo "ERROR: $part is mounted; formatting cancelled." >&2; return 1
  fi
  local holders_dir holder active_swaps swap_dev backing_devices backing_dev part_real backing_real
  holders_dir="/sys/class/block/${part##*/}/holders"
  if [ -d "$holders_dir" ]; then
    holder=$(find "$holders_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null) || return 1
    if [ -n "$holder" ]; then
      echo "ERROR: $part is in use by an active device ($(basename "$holder")); formatting cancelled." >&2
      return 1
    fi
  fi
  part_real=$(readlink -f -- "$part") || return 1
  active_swaps=$(sudo swapon --noheadings --raw --show=NAME) || return 1
  while IFS= read -r swap_dev; do
    [ -n "$swap_dev" ] || continue
    [ -b "$swap_dev" ] || continue
    backing_devices=$(lsblk --inverse --noheadings --raw --paths --output NAME "$swap_dev") || return 1
    while IFS= read -r backing_dev; do
      [ -n "$backing_dev" ] || continue
      backing_real=$(readlink -f -- "$backing_dev") || return 1
      if [ "$backing_real" = "$part_real" ]; then
        echo "ERROR: $part is active swap; formatting cancelled." >&2
        return 1
      fi
    done <<< "$backing_devices"
  done <<< "$active_swaps"
}
```
| Partition | Description |
|---|---|
| EFI | 1 GiB FAT32 |
| SWAP | 8 GiB (required; the commands below assume this partition layout) |
| LUKS | 800 GiB main system volume |

---

## Create the partition table

> `G` in the `sgdisk` commands means GiB. The partitions below allocate 809 GiB in total.
> Even if the capacity and mounted-device checks pass, `sgdisk -Z` irreversibly removes the existing partition table. Verify the model and serial number one final time.

```bash
set -Eeuo pipefail
# The disk or its usage state may have changed since the first check; check again.
assert_disk_unused
printf '\nFINAL CHECK — the disk below will be repartitioned irreversibly:\n'
printf '  Device: %s\n  Model: %s\n  Serial: %s\n  Size: %s bytes\n' \
  "$DISK_REAL" "${DISK_MODEL:-unknown}" "${DISK_SERIAL:-unknown}" "$DISK_BYTES"
read -r -p "Type exactly 'WIPE $DISK_REAL': " WIPE_CONFIRMATION
if [ "$WIPE_CONFIRMATION" != "WIPE $DISK_REAL" ]; then
  echo "Cancelled; nothing was written to the disk." >&2
  exit 1
fi

sudo sgdisk -Z "$DISK_REAL"
sudo sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:EFI  "$DISK_REAL"
sudo sgdisk -n 2:0:+8G   -t 2:8200 -c 2:SWAP "$DISK_REAL"
sudo sgdisk -n 3:0:+800G -t 3:8309 -c 3:LUKS "$DISK_REAL"
sudo partprobe "$DISK_REAL"
sudo udevadm settle

# Verify that exactly three partitions were created and belong to the same disk
# before continuing. This block stops on command failure because of set -e.
assert_disk_identity
assert_partition_on_target "${PART_PREFIX}1"
assert_partition_on_target "${PART_PREFIX}2"
assert_partition_on_target "${PART_PREFIX}3"
printf 'Partition table created and all three partition devices verified. Review the output before formatting.\n'
```
---

# 🔒 3. LUKS2 setup

```bash
set -Eeuo pipefail
assert_disk_unused
assert_partition_on_target "${PART_PREFIX}3"
if [ -e /dev/mapper/cryptroot ]; then
  echo "ERROR: /dev/mapper/cryptroot already exists; inspect it before closing or continuing." >&2
  exit 1
fi
printf "The LUKS2 header on %s will be overwritten; verify this is the new installation target before continuing.\n" "${PART_PREFIX}3"
read -r -p "Type exactly 'FORMAT LUKS ${PART_PREFIX}3' to confirm LUKS formatting: " LUKS_CONFIRMATION
if [ "$LUKS_CONFIRMATION" != "FORMAT LUKS ${PART_PREFIX}3" ]; then
  echo "Cancelled; LUKS was not formatted." >&2
  exit 1
fi
sudo cryptsetup luksFormat "${PART_PREFIX}3" --type luks2
sudo cryptsetup isLuks "${PART_PREFIX}3"
sudo cryptsetup open "${PART_PREFIX}3" cryptroot
sudo cryptsetup status cryptroot
```
---

# 💽 4. Filesystems

```bash
set -Eeuo pipefail
assert_disk_identity
assert_partition_on_target "${PART_PREFIX}1"
assert_partition_on_target "${PART_PREFIX}2"
sudo cryptsetup isLuks "${PART_PREFIX}3"
sudo cryptsetup status cryptroot >/dev/null
if [ -e /dev/mapper/cryptroot ] && [ -n "$(findmnt -rn -S /dev/mapper/cryptroot -o TARGET || true)" ]; then
  echo "ERROR: /dev/mapper/cryptroot is already mounted; formatting cancelled." >&2
  exit 1
fi
printf '\nWARNING: EFI, swap, and encrypted Btrfs filesystems will be created. Existing contents on these partitions may be erased.\n'
read -r -p "Type exactly 'FORMAT $DISK_REAL': " FORMAT_CONFIRMATION
if [ "$FORMAT_CONFIRMATION" != "FORMAT $DISK_REAL" ]; then
  echo "Cancelled; filesystems were not created." >&2
  exit 1
fi
sudo mkfs.fat -F32 "${PART_PREFIX}1"
sudo mkswap "${PART_PREFIX}2"
sudo mkfs.btrfs -L nixos /dev/mapper/cryptroot
sudo blkid "${PART_PREFIX}1" "${PART_PREFIX}2" /dev/mapper/cryptroot
```
---

# 🌳 5. Btrfs subvolumes

```bash
sudo mount /dev/mapper/cryptroot /mnt

sudo btrfs subvolume create /mnt/@
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@log
sudo btrfs subvolume create /mnt/@snapshots
# NOTE: @home/.snapshots cannot be created here because @home is not mounted yet.
# The subvolume required by services.snapper.configs.home (SUBVOLUME="/home")
# must be created after @home is mounted below (see Section 6).

sudo umount /mnt
```
---

# 📦 6. Mount the filesystems

```bash
sudo mount -o subvol=@,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt

sudo mkdir -p /mnt/{boot,home,nix,var/log,.snapshots}

# Create this only AFTER mounting @home (below).

sudo mount -o subvol=@home,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home

# @home is mounted; create and mount the Home Snapper subvolume now.
sudo btrfs subvolume create /mnt/home/.snapshots
sudo mount -o subvol=@home/.snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home/.snapshots

sudo mount -o subvol=@nix,noatime,nodatacow,ssd,discard=async /dev/mapper/cryptroot /mnt/nix

sudo mount -o subvol=@log,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/var/log

sudo mount -o subvol=@snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/.snapshots

sudo mount "${PART_PREFIX}1" /mnt/boot

sudo swapon "${PART_PREFIX}2"

# Impermanence is not enabled in this configuration; no persistent-home directory is needed.
```
---

# 🧠 7. Set up the repository (correct method)

`nixos-generate-config` already creates `/mnt/etc/nixos/configuration.nix` and
`hardware-configuration.nix`, so cloning the repository directly into `/mnt/etc/nixos`
causes an “already exists and is not an empty directory” error. Clone it into a separate
directory first, copy the machine-specific `hardware-configuration.nix` into the clone,
and then replace the generated target configuration with the repository contents:

```bash
set -Eeuo pipefail
sudo nixos-generate-config --root /mnt

git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/hardware-configuration.nix

# Keep the generated files as a unique backup before replacing the install tree.
TARGET_BACKUP="/mnt/etc/nixos-generated-backup-$(date +%Y%m%d-%H%M%S)"
if [ -e "$TARGET_BACKUP" ] || [ -L "$TARGET_BACKUP" ]; then
  echo "ERROR: Backup path already exists: $TARGET_BACKUP" >&2
  exit 1
fi
sudo mv /mnt/etc/nixos "$TARGET_BACKUP"
sudo mkdir -p /mnt/etc/nixos
# Copy repository contents but do not copy Git history into the target system configuration.
tar --exclude='./.git' -C /tmp/repo -cf - . | sudo tar --no-same-owner -C /mnt/etc/nixos -xf -
```
> ℹ️ The `hardware-configuration.nix` file was replaced by the version generated for
> **your own machine** by `nixos-generate-config`, using the `cp` command above, so its
> UUIDs should already be correct. You normally do not need to edit them manually; check
> them if the output of `lsblk -f` does not match what you expect.
>
> **Swap encryption:** the example configuration uses `randomEncryption.enable = true;`
> to encrypt the swap partition with a random key on each activation. Preserve your own
> swap device path in the `swapDevices` entry generated by `nixos-generate-config` and add
> `randomEncryption.enable = true;` to that same entry. Edit
> `sudoedit /mnt/etc/nixos/nixos/hardware-configuration.nix`. You may also set
> `priority = 10;`, as in the reference configuration; zram has priority 100 and is used
> first. Random-key swap encryption does not use a persistent LUKS key, so old swap
> contents cannot be decrypted after a reboot.
>
> The repository layout is preserved, so the flake is under `/mnt/etc/nixos/nixos`.
> The path before `#nixos` in the installation command must point to that directory
> (see the next step).

---

# ⚠️ 7b. Five settings to review and customize as needed

The manual path copies the `nixos/` directory as-is and does not prompt for machine-specific
values. Before installation, review these five settings in `home.nix` and customize the ones
that do not match your setup. Some defaults (such as `hyprlandMonitorMode = "preferred"`) are
valid as-is; placeholder identity values and paths should be replaced where applicable:

| # | Setting | Default | What happens if it is wrong |
|---|---|---|---|
| 1 | `hyprlandMonitorMode` | `"preferred"` | Preferred mode by default. Set a fixed mode such as `"2560x1440@170"` when needed; the installer accepts only `preferred` or a width × height mode with an optional refresh rate. |
| 2 | `monitorOutput` | `""` (empty) | The exact output name used for the Hyprland monitor rule and optional `mpvpaper` wallpaper. A manually empty value keeps Hyprland's catch-all monitor rule and disables live wallpaper; the installer asks for a real output name. |
| 3 | `gitName` | `"changeme"` | Commits are attributed to a placeholder name. |
| 4 | `gitEmail` | `"you@example.com"` | Commits are attributed to a placeholder email address. |
| 5 | `wallpaperVideo` | `~/Downloads/arthur-leywin-….mp4` | If the file is missing, `Unit.ConditionPathExists` prevents the service from starting. A login-time warning is shown only when `monitorOutput` is non-empty. |

Manual installation is recommended; fill in these values yourself. `install.sh` is optional
for advanced users migrating an existing NixOS system and carries additional risk because
it modifies system configuration and VM XML automatically:

```bash
# Find the monitor output name.
hyprctl monitors | grep -oPm1 '^Monitor \K\S+'
# Or read it from DRM.
for c in /sys/class/drm/card*-*; do
  [ "$(cat $c/status 2>/dev/null)" = connected ] && basename $c | sed 's/card[0-9]*-//'
done
```
Before installation, while the target system is mounted under `/mnt`, edit the `let` block
near the top of `/mnt/etc/nixos/nixos/home.nix` (approximately lines 4–12):

```nix
  gitName            = "Your Name";
  gitEmail           = "you@example.com";
  monitorOutput      = "DP-1";                              # Exact output name from hyprctl monitors
  hyprlandMonitorMode = "2560x1440@170";                   # Or "preferred"
  wallpaperVideo     = "${config.home.homeDirectory}/Downloads/wallpaper.mp4";
```
> The Lua `hl.monitor` rule uses `monitorOutput` and `hyprlandMonitorMode`. An empty
> `monitorOutput` is a catch-all for manual setups; it does not mirror workspaces. Prefer
> an explicit name such as `DP-1` on a multi-monitor system.

### Native Hyprland Lua configuration

Hyprland 0.55+ uses the Lua API. The config is declared inline in `nixos/home.nix` and
Home Manager writes it to `~/.config/hypr/hyprland.lua`; the greetd wrapper and
`HYPRLAND_CONFIG` both point to that exact file. There is no parallel `hyprland.conf`
source to drift out of sync. Old manually copied `.conf` files are not the active config.

Check this after installation:

```bash
echo "$HYPRLAND_CONFIG"   # /home/localhost/.config/hypr/hyprland.lua
hyprctl configversion
hyprctl monitors
```
The Lua configuration keeps the existing gaming rules, Turkish keyboard layout,
Waybar/notification startup, scratchpads, translation helpers, and optional `mpvpaper`
services. A real monitor name is used for the output rule; select `preferred` or a fixed
mode in `hyprlandMonitorMode`.
---

# 🔑 8. Passwords (root + localhost)

`configuration.nix` reads the `localhost` user's password from
`hashedPasswordFile = "/etc/nixos/hashedPassword"`. For a clean installation, create this
file **before installation** at the target system's root, i.e. `/mnt/etc/nixos/hashedPassword`.
Do not overwrite an existing file containing a valid hash. If the file is missing or empty,
the following commands create a new hash:

```bash
sudo install -d -m 755 /mnt/etc/nixos
if [ ! -s /mnt/etc/nixos/hashedPassword ]; then
  HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
  printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
fi
sudo chown root:root /mnt/etc/nixos/hashedPassword
sudo chmod 600 /mnt/etc/nixos/hashedPassword
sudo test -s /mnt/etc/nixos/hashedPassword
password_meta=$(sudo stat -c '%U:%G:%a' /mnt/etc/nixos/hashedPassword)
[ "$password_meta" = "root:root:600" ] || { echo "hashedPassword must be root:root:600 (found: $password_meta)" >&2; exit 1; }
```
> `tee` alone can create a file with more permissive permissions, so do not skip the
> ownership and `0600` permission steps. `nix-shell -p whois` temporarily provides
> `mkpasswd`; the hash command prompts for the password interactively.
>
> The `localhost` password is for the Hyprland/tuigreet desktop session. The root password
> is separate and is used for console/emergency access; set it after installation succeeds
> (Section 9).

> 🔑 **SSH access:** the SSH server listens on TCP port 22 and the firewall allows this
> port. Password login is permitted only for the `localhost` user, root SSH login is
> disabled, and Fail2ban monitors failed logins. Use a strong, unique password and keep SSH
> reachable only from networks you trust. Connect from another device with
> `ssh localhost@<server-ip>`; find the server address with `ip -br address`. For safer
> key-based access, generate a key with `ssh-keygen -t ed25519` and add its `.pub` contents
> to `users.users.localhost.openssh.authorizedKeys.keys`. After confirming that key login
> works, you can set `PasswordAuthentication = false`.

---

# ⚡ 9. Install NixOS

Because `flake.nix` is in the `nixos/` subdirectory rather than the repository root, the
path before `#nixos` must include that subdirectory:

```bash
# On the first run, review and accept the configured binary cache if trusted.
sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos
```
After installation succeeds, while the target system is still mounted under `/mnt`, set
or update the root password. If run before installation has completed, `nixos-enter` may
refuse to recognize the target system:

```bash
sudo nixos-enter --root /mnt -c 'passwd root'
```
> **Important:** The commands below that use `/etc/nixos/nixos` must be run on the installed
> system after the first reboot. Do not run them from the Live ISO; the target system is
> still mounted under `/mnt` there. To select a new kernel before the first installation,
> perform the equivalent update against `/mnt/etc/nixos/nixos` before running `nixos-install`.
>
> **Updating the kernel input:** `flake.nix` uses the `linuxPackages-cachyos-rt-bore-lto`
> package from the CachyOS upstream `master` input; the kernel version is not hard-coded.
> `flake.lock` records the resolved source revision for reproducibility. To move to a newer
> upstream revision, back up the current lock file, update only the CachyOS input, and review
> the resulting change:

> ```bash
> sudo cp /etc/nixos/nixos/flake.lock /tmp/flake.lock.before-cachyos-update
> sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel
> sudo diff -u /tmp/flake.lock.before-cachyos-update /etc/nixos/nixos/flake.lock || test "$?" -eq 1
> ```
> The `diff` command returns `1` when the files differ and `2` on an error. If Nix asks to
> trust cache settings, inspect the URL and public key and accept them only if you trust
> them; do not use `--accept-flake-config` to bypass the review. The Fish `nup` shortcut
> performs the same targeted update from any directory and does not automatically accept
> settings. Do not switch the system until `dry-activate` succeeds.
> **The RT-Bore-LTO LTO variant is not published in the upstream binary cache**; the kernel
> is expected to build locally, which may take a long time or fail due to source/toolchain
> issues. `overlays.pinned` aligns the kernel and target nixpkgs revision but cannot create
> a missing cache artifact.

**Reflex selection:** the system enables `low_latency_layer` globally but does not force the Reflex interface on every application. Native Linux CS2 uses the default AMD Anti-Lag interface. For a compatible Proton title that supports Reflex, try `LOW_LATENCY_LAYER_REFLEX=1 %command%` in that game's Steam launch options; only add `DXVK_CONFIG="dxgi.hideAmdGpu = True"` if Reflex is not exposed in the game settings.

**CS2 / Source 2 low-latency note:** the [low_latency_layer v0.2.0 upstream release notes](https://github.com/Korthos-Software/low_latency_layer/releases/tag/v0.2.0) describe in-game FPS caps causing frame-pacing problems while the layer is enabled. Until the upstream issue is fixed, use `fps_max 0` in the CS2 console. External limiters such as MangoHud have not been reported to cause the same issue. If stuttering persists, compare frame times after disabling the layer only for CS2 with `DISABLE_LOW_LATENCY_LAYER=1 %command%` in Steam launch options.

**OBS Vulkan capture compatibility:** upstream `low_latency_layer` v0.2.0 also documents an incompatibility with the `obs_vkcapture` Vulkan layer. If capture or recording fails, test the game with `DISABLE_LOW_LATENCY_LAYER=1 %command%` and compare behavior.

---

> ⚠️ **VM preparation:** the XML and qcow2 files are prepared after installation on the first boot; see Section 10b.

---

# 🔄 10. Reboot

```bash
sudo reboot
```
---

# 🖥️ 10b. Register the VM with libvirt (after the first reboot)

> **Correction (2026-10-04):** this step was missing from the earlier documentation. If it
> is skipped, the domain remains undefined; the `if [ "$GUEST" != "$TARGET_VM" ]; then exit 0`
> filter in `nixos/hooks/qemu` (`TARGET_VM="win10"`) never matches, so the GPU is **never**
> bound to `vfio-pci`. In other words, the VFIO flow does not run at all.
>
> **USB keyboard/mouse IDs:** the default XML actively passes through USB devices `1532:0098`
> and `05ac:024f`; the installer does not detect these IDs automatically. Verify with
> `lsusb -nn` that both IDs belong to the devices you intend to pass through. If either is
> wrong, edit the source template `$REPO/vm-xml/win10.xml` before creating a new deployed XML.
> If `/var/lib/libvirt/win10.xml` already exists, edit the deployed file instead; editing only
> the source template does not update an existing VM definition. Then re-define the active file
> with `sudo virsh define /var/lib/libvirt/win10.xml`.

> **Check ISO prerequisites before defining or starting the VM.** The default XML expects
> `Win10_22H2_English_x64v1.iso` and `virtio-win-0.1.285.iso` under
> `/var/lib/libvirt/images/`. Confirm that both files exist at the exact paths shown by the
> deployed XML; if you use different filenames or locations, edit those XML source paths first.
> A missing Windows or VirtIO ISO prevents the VM from starting or completing Windows setup.
>
```bash
# Run these commands after the first reboot, not from the live ISO.
# Keep the repository checkout outside /etc/nixos, as described in README.md.
set -euo pipefail
REPO="$HOME/nixos-hyprland-vfio"  # change this if the checkout is elsewhere
VM_XML=/var/lib/libvirt/win10.xml
test -f "$REPO/scripts/sync-vm-xml.py"
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu

# Remember whether this is an existing VM before the helper writes/updates its XML.
if sudo test -e "$VM_XML" || sudo test -L "$VM_XML"; then
  EXISTING_VM_XML=1
else
  EXISTING_VM_XML=0
fi

# Copy the exact GPU_PCI and GPU_AUDIO values from the deployed /etc/nixos/nixos/hooks/qemu.
# The helper generates a fresh UUID/MAC for a new XML and preserves an existing VM XML.
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

# The Windows and VirtIO ISO paths in $VM_XML must already point to existing files.
sudo virsh define "$VM_XML"
sudo virsh list --all     # win10 should appear as "shut off"
```
### Temporary display channel on first start (optional diagnostics)

The production XML uses `<video><model type="none"/></video>` and therefore provides no VNC
console. If you need to debug the first launch, run the following commands from the repository
root to generate a **separate copy of the deployed XML with synchronized PCI addresses**.
The main `/var/lib/libvirt/win10.xml` file is not modified:

```bash
sudo python3 scripts/prepare-vm-diagnostic.py \
  --input /var/lib/libvirt/win10.xml \
  --output /var/lib/libvirt/win10-diagnostic.xml
sudo virsh define /var/lib/libvirt/win10-diagnostic.xml
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```
The hook may terminate local graphical sessions on `seat0` without filtering by user, so do
not start the VM from a normal graphical shell. `systemd-run` creates a separate service
started by the system manager; this command does not target the SSH session. Check the result
and VNC display from another session:

```bash
sudo journalctl -u vmstart.service -b --no-pager
sudo virsh vncdisplay win10
```
VNC listens only on `127.0.0.1`. After testing, shut down the VM and restore the production
XML definition with `sudo virsh define /var/lib/libvirt/win10.xml`. This diagnostic setup is
only for startup troubleshooting; it is not a permanent gaming configuration.

> ⚠️ **PCI addresses (clean install):** if `install.sh` was not run, both the hook and VM XML
> use the repository defaults `0000:0b:00.0` / `0000:0b:00.1`. Verify with `lspci -Dnn` that
> these are the target GPU's display and audio functions. If they differ, update **both** files:
>
> - `/etc/nixos/nixos/hooks/qemu`: the `GPU_PCI` and `GPU_AUDIO` values near the top.
> - `$REPO/vm-xml/win10.xml` is the source template; keep it separate from the deployed VM XML.
>   Do not copy it over an existing VM. After updating the deployed hook, use the
>   `scripts/sync-vm-xml.py` command documented above to synchronize PCI addresses safely; it
>   backs up and preserves an existing deployed XML, and only writes to
>   `/var/lib/libvirt/win10.xml`.
>
> Run `python3 scripts/test-vm-xml.py` from the repository root. It checks that the hook and XML
> addresses match each other, but it cannot prove those addresses identify the correct physical
> devices on your machine. Then rebuild the hook with
> `sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos`. Finally, define the synchronized
> active file with `sudo virsh define /var/lib/libvirt/win10.xml`. Updating only the hook does not
> update the VM's PCI resources, and updating only an XML does not activate the new hook.

> ⚠️ The XML contains fixed disk and NVRAM paths. If they do not match your own files,
> `virsh start win10` fails because a disk or NVRAM file cannot be found.
>
> ⚠️ **Start the VM through a detached systemd unit.** The hook terminates local graphical
> sessions with `loginctl terminate-seat seat0`; it intentionally does not terminate SSH
> sessions. If a process is still using the GPU, the hook cancels the handoff and attempts
> rollback instead of continuing. Start it with:
>
> ```bash
> sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
> sudo journalctl -u vmstart.service -b --no-pager
> ```
> Keep a physical recovery TTY available and verify on real hardware that an SSH connection
> from a second device survives while the VM starts.
>
> **Verify the domain:** `sudo virsh dominfo win10` should show the name, UUID, and PCI host
> devices. Monitor the hook with `sudo journalctl -u libvirtd -f` and
> `sudo tail -f /var/log/libvirt/qemu/win10.log`.
>
> ⚠️ **Hook log:** `sudo cat /var/log/libvirt/vfio.log` records whether the GPU was bound to
> `vfio-pci`, its reset state, and (where available for Navi 2x) recovery steps.
>
> **Session scope:** the hook does not use `HOST_USER` or call `loginctl terminate-user`.
> `loginctl terminate-seat seat0` terminates local sessions on `seat0` without filtering by
> user, but it does not target SSH sessions. If a background process still holds the GPU,
> the GPU-use check safely aborts the handoff.
>
> This behavior cannot be changed by adding an environment variable: `virtualisation.libvirtd.hooks.qemu`
> entries are file paths, and this hook does not currently read a user-selection variable. To
> change the session scope, deliberately modify the session-management code in `nixos/hooks/qemu`,
> test it, and rebuild NixOS. The separate `VFIO_ALLOW_SUSPEND_RECOVERY` setting only enables an
> optional VFIO recovery path; it does not change user/seat selection.

### Historical hardware validation with the previous kernel — 16 October 2026

> **Historical scope:** the successful result recorded here applies to the previous standard BORE-LTO
> kernel. At the time of this 16 October entry, RT-Bore-LTO had not yet been validated.
>
> On 2026-10-16, the repository owner reported that the rebuild and standard BORE-LTO kernel build
> completed, the Windows VM started and shut down, and the host display/Hyprland session returned.
> The later RT-Bore-LTO result is recorded separately below; neither owner-reported result is an
> independent reproduction or a guarantee for other hardware.

### Target-system validation update — 23 October 2026

> The project owner reports that NixOS rebuilt successfully, the RT-Bore-LTO ThinLTO kernel compiled,
> the Windows VM started and shut down normally, and control returned to Hyprland on the target
> machine. This is owner-reported validation, not independent reproduction. Since this kernel variant
> is not available in the upstream binary cache, a newly selected upstream revision still needs a
> local build and a repeat of the boot, VM start/shutdown, display recovery, and second-start checks.

---

# 🧠 After installation

## Update the system

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```
```bash
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
```
## Optional local WuWa translation model (`wuwa-gemma`, based on Aya Expanse 8B)

`wuwa-gemma` is a custom Ollama name created from `aya-expanse:8b`; it is not part of the
Gemma model family. The model service is not started automatically, so start it manually
before using WuWa OCR translation for the first time.

```bash
sudo systemctl start wuwa-gemma-init
sudo systemctl status wuwa-gemma-init --no-pager
```
After the service completes successfully and the `wuwa-gemma` model appears in Ollama,
start the OCR script. If the model is missing, the script now warns and exits.

## Reboot

```bash
sudo reboot
```
> ⚠️ Kernel parameters and initrd/VFIO module changes may require a reboot. A reboot alone
> does not prove that IOMMU is enabled. Check with `dmesg | grep -Ei "AMD-Vi|IOMMU"` and
> `/sys/kernel/iommu_groups/`; IOMMU/AMD-Vi must also be enabled in BIOS/UEFI. If the installer
> cannot resolve IOMMU groups for the GPU and its audio function, it stops before deploying
> configuration files. If unrelated devices share a group, inspect the group members and do
> not continue without explicitly acknowledging the risk. The hook running after `switch` does
> not by itself prove that IOMMU is active or that isolation is safe.

## Check logs

```bash
sudo journalctl -u libvirtd
```
```bash
cat ~/.local/share/hyprland/hyprland.log
```
---

# ⚠️ Important notes

- The display goes black during VFIO handoff; this is expected.
- Enter the correct GPU PCI ID.
- `nixos/configuration.nix` sets the default hostname to `nixos`; change it before activation if the target machine should use a different name.
- `hardware-configuration.nix` is machine-specific.
- `/home/.snapshots` is required on Btrfs systems because `hardware-configuration.nix` mounts it with `neededForBoot = true`. For a manual install, run `sudo btrfs subvolume create /home/.snapshots` only if that subvolume does not already exist, then verify the mount definition and actual mount. When `install.sh` is used, it creates and verifies the missing subvolume if `/home` is Btrfs; do not run the command again unnecessarily. If the path exists but is not a Btrfs subvolume, do not delete or convert it automatically; inspect its contents and mount state first.
- UEFI is required.
- SSH key authentication is recommended.
- The LUKS passphrase is requested at boot.

---

# 💡 Note

The remaining disk space can be used for:
- dual boot
- another distribution
- test systems

---

# 📄 License

MIT License

# 🇹🇷 NixOS Hyprland + VFIO Kurulum Rehberi

Bu rehber AMD sistemler için optimize edilmiş **NixOS + LUKS2 + Btrfs + Hyprland + VFIO** kurulum akışıdır.

---

# ⚙️ Ön Gereksinimler

- NixOS 26.05 Live ISO
- UEFI sistem
- AMD Ryzen CPU
- AMD Radeon RX 6000/7000 GPU
- En az 50GB boş disk

---

# 🚀 1. Canlı Ortam

ISO → UEFI başlat

```bash
nmtui
```

Klavyeyi TR yap:

```bash
loadkeys trq
```

---

# 💾 2. Disk Bölümlendirme

| Bölüm | Açıklama |
|------|----------|
| EFI | 512MB FAT32 |
| SWAP | 8GB (opsiyonel) |
| LUKS | Ana sistem |

---

## Disk oluşturma

```bash
sudo sgdisk -Z /dev/nvme0n1

sudo sgdisk -n 1:0:+1G  -t 1:ef00 -c 1:EFI  /dev/nvme0n1
sudo sgdisk -n 2:0:+8G  -t 2:8200 -c 2:SWAP /dev/nvme0n1
sudo sgdisk -n 3:0:+800G -t 3:8309 -c 3:LUKS /dev/nvme0n1

sudo partprobe /dev/nvme0n1
```

---

# 🔒 3. LUKS2 Kurulum

```bash
cryptsetup luksFormat /dev/nvme0n1p3 --type luks2
cryptsetup open /dev/nvme0n1p3 cryptroot
```

---

# 💽 4. Dosya Sistemleri

```bash
mkfs.fat -F32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
mkfs.btrfs -L nixos /dev/mapper/cryptroot
```

---

# 🌳 5. Btrfs Subvolumes

```bash
mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots

umount /mnt
```

---

# 📦 6. Mount İşlemleri

```bash
mount -o subvol=@,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{boot,home,nix,var/log,.snapshots}

mount -o subvol=@home,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home

mount -o subvol=@nix,noatime,nodatacow,ssd,discard=async /dev/mapper/cryptroot /mnt/nix

mount -o subvol=@log,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/var/log

mount -o subvol=@snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/.snapshots

mount /dev/nvme0n1p1 /mnt/boot

swapon /dev/nvme0n1p2
```

---

# 🧠 7. NixOS Config

```bash
nixos-generate-config --root /mnt
```

---

# 📁 8. Repo Kurulumu (DOĞRU YÖNTEM)

```bash
git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /mnt/etc/nixos
```

---

# 🔑 9. Root Şifre

```bash
nixos-enter --root /mnt -c 'passwd root'
```

---

# ⚡ 10. Kurulum

```bash
nixos-install --flake /mnt/etc/nixos#nixos
```

---

# 🔄 11. Reboot

```bash
reboot
```

---

# 🧠 Kurulum Sonrası

## Sistem güncelle

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Log kontrol

```bash
journalctl -u libvirtd
```

```bash
cat ~/.local/share/hyprland/hyprland.log
```

---

# ⚠️ Önemli Notlar

- VFIO sırasında ekran kararır (normal)
- GPU PCI ID doğru girilmelidir
- hardware-configuration.nix cihaz bağımlıdır
- UEFI zorunludur
- SSH key authentication önerilir
- LUKS şifresi açılışta istenir

---

# 💡 Not

Kalan disk alanı:
- dual boot
- başka distro
- test sistemleri için kullanılabilir

---

# 📄 Lisans

MIT License

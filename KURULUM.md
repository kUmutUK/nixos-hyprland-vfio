# 🇹🇷 NixOS Hyprland + VFIO Kurulum Rehberi

Bu rehber AMD sistemler için optimize edilmiş **NixOS + LUKS2 + Btrfs + Hyprland + VFIO** kurulum akışıdır.

---

# ⚙️ Ön Gereksinimler

- NixOS 26.05 Live ISO
- UEFI sistem
- AMD Ryzen CPU
- AMD Radeon RX 6000/7000 GPU
- En az 800 GB boş disk (aşağıdaki bölümlendirme 800 GB kullanıyor)

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
# NOT: @home/.snapshots alt hacmi BURADA oluşturulamaz — @home henüz mount
# edilmedi. services.snapper.configs.home (SUBVOLUME="/home") için gereken
# alt hacim, aşağıda @home mount edildikten SONRA oluşturulur (bkz. §6).

umount /mnt
```

---

# 📦 6. Mount İşlemleri

```bash
mount -o subvol=@,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{boot,home,nix,var/log,.snapshots}

# @home mount EDİLDİKTEN SONRA oluşturulur (aşağıda)

mount -o subvol=@home,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home

# @home mount edildi → şimdi home snapper alt hacmini oluştur ve bağla
btrfs subvolume create /mnt/home/.snapshots
mount -o subvol=@home/.snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home/.snapshots

mount -o subvol=@nix,noatime,nodatacow,ssd,discard=async /dev/mapper/cryptroot /mnt/nix

mount -o subvol=@log,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/var/log

mount -o subvol=@snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/.snapshots


mount /dev/nvme0n1p1 /mnt/boot

swapon /dev/nvme0n1p2
```

---

# 🧠 7. Repo Kurulumu (DOĞRU YÖNTEM)

`nixos-generate-config` zaten `/mnt/etc/nixos/configuration.nix` ve
`hardware-configuration.nix` dosyalarını oluşturur — bu yüzden repo'yu
doğrudan `/mnt/etc/nixos`'a klonlamaya çalışmak "already exists and is
not an empty directory" hatası verir. Önce ayrı bir dizine klonlayın,
sadece donanıma özel dosyayı (`hardware-configuration.nix`) oradan
alın, gerisini repo'nunkiyle değiştirin:

```bash
nixos-generate-config --root /mnt

git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/hardware-configuration.nix

rm -rf /mnt/etc/nixos
mkdir -p /mnt/etc/nixos
cp -r /tmp/repo/. /mnt/etc/nixos/
```

> ⚠️ `hardware-configuration.nix`'i UUID'lerinizle güncellemeyi unutmayın
> (bkz. Notlar). Repo'daki flake `nixos/flake.nix`'te olduğu için kurulum
> komutu da o alt dizini işaret etmeli — bir sonraki adıma bakın.

---

# 🔑 8. Root Şifre

```bash
nixos-enter --root /mnt -c 'passwd root'
```

---

# ⚡ 9. Kurulum

flake.nix repo kökünde değil, `nixos/` alt dizininde olduğu için `#nixos`
öncesindeki yol da buna göre verilmeli:

```bash
nixos-install --flake /mnt/etc/nixos/nixos#nixos
```

---

# 🔄 10. Reboot

```bash
reboot
```

---

# 🧠 Kurulum Sonrası

## Sistem güncelle

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
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
- Mevcut bir sistemi güncelliyorsanız /home/.snapshots alt hacmini
  `sudo btrfs subvolume create /home/.snapshots` ile ÖNCE oluşturun,
  aksi halde neededForBoot yüzünden acil kipe düşersiniz
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

# 🇹🇷 NixOS Hyprland Gaming + VFIO – Türkçe Kurulum Rehberi

Bu rehber, AMD işlemci ve AMD ekran kartı için optimize edilmiş NixOS yapılandırmasını adım adım kurmanıza yardımcı olur.

---

## ⚙️ Ön Gereksinimler

* NixOS 26.05 (unstable) canlı ISO veya mevcut bir NixOS kurulumu
* UEFI önyükleme
* En az 50 GB boş disk alanı
* AMD Ryzen işlemci + AMD Radeon RX 6000/7000 serisi ekran kartı

---

## 🔌 Adım 1 – Canlı Ortamı Başlatın

NixOS ISO’sunu USB’ye yazdırın ve UEFI modunda başlatın.
İnternete bağlanın (kablolu veya `nmtui` ile Wi-Fi).

---

## 💽 Adım 2 – Diskleri Hazırlayın

Bu yapılandırma **LUKS2 şifreleme** ve **Btrfs** üzerine kuruludur.

### Örnek disk yapısı:

* `/dev/nvme0n1p1` – EFI (FAT32, 512 MB)
* `/dev/nvme0n1p2` – Swap (isteğe bağlı)
* `/dev/nvme0n1p3` – LUKS → Btrfs (kök)

Diskleri kendi ihtiyacınıza göre bölümlendirin.

---

## 🔐 Adım 3 – LUKS ve Btrfs Oluşturun

```bash
# LUKS konteyneri
cryptsetup luksFormat --type luks2 /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 cryptroot

# Btrfs dosya sistemi
mkfs.btrfs -L NixOS /dev/mapper/cryptroot

# Subvolume oluşturma
mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Mount işlemleri
mount -o subvol=@,compress=zstd:1,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}
mount -o subvol=@home,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,noatime,nodatacow /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,noatime /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@snapshots,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/.snapshots
mount /dev/nvme0n1p1 /mnt/boot

# Swap (isteğe bağlı)
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2
```

---

## 🛠️ Adım 4 – NixOS’u Kurun

```bash
nixos-generate-config --root /mnt
```

Oluşan `/mnt/etc/nixos/hardware-configuration.nix` dosyasını saklayın.

---

## 📦 Adım 5 – Repo ve Kurulum

```bash
git clone https://github.com/kUmutUK/Declarative-NixOS-Gaming-VFIO-Setup-Hyprland-AMD-GPU-Passthrough- /tmp/nixos-config
cd /tmp/nixos-config
chmod +x install.sh
./install.sh
```

### Betik sizden şunları ister:

* GPU PCI adresleri (`lspci -nn | grep -i vga`)
* Monitör çıkışı (örn. `DP-3`)
* Hyprland monitor satırı
* Git kullanıcı bilgileri

---

## 📁 Adım 6 – hardware-configuration.nix

```bash
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/
```

UUID kontrolü:

```bash
lsblk -f
```

---

## 🔑 Adım 7 – Parola Oluşturun

```bash
mkpasswd -m sha-512 | sudo tee /etc/nixos/hashedPassword
```

---

## ⚡ Adım 8 – Sistemi Derleyin

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Kurulum sonrası sistemi yeniden başlatın.

---

## 🎉 Kurulum Sonrası

```bash
waydroid init -f
ollama pull llama3
cat /var/log/libvirt/vfio.log
```

---

## 🧪 Sorun Giderme

### Hyprland açılmazsa:

```bash
cat ~/.local/share/hyprland/hyprland.log
```

### VFIO çalışmazsa:

```bash
journalctl -u libvirtd
```

### Wi-Fi yoksa:

```bash
nmtui
```

---

## 💡 Notlar

* Single-GPU passthrough sırasında ekran kararır
* GPU PCI ID’leri doğru olmalı
* SSH için anahtar kullanımı önerilir

---

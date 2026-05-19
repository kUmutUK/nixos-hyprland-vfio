# NixOS Hyprland + VFIO Kurulum Rehberi

Bu rehber, AMD işlemci ve AMD ekran kartı için optimize edilmiş NixOS yapılandırmasını adım adım kurmanıza yardımcı olur.

---

# ⚙️ Ön Gereksinimler

- NixOS 26.05 canlı ISO
- UEFI sistem
- En az 50 GB boş alan
- AMD Ryzen işlemci
- AMD Radeon RX 6000/7000 serisi ekran kartı

---

# 🚀 Adım 1 — Canlı Ortamı Başlatın

NixOS ISO’sunu USB’ye yazdırın ve UEFI modunda başlatın.

İnternete bağlanın:

```bash
nmtui
```

---

# 💾 Adım 2 — Disk Bölümlendirme

Örnek yapı:

| Bölüm | Açıklama |
|---|---|
| `/dev/nvme0n1p1` | EFI (512MB FAT32) |
| `/dev/nvme0n1p2` | Swap (opsiyonel) |
| `/dev/nvme0n1p3` | LUKS2 → Btrfs |

Diskleri ihtiyacınıza göre bölümlendirin.

---

# 🔒 Adım 3 — LUKS2 + Btrfs

## LUKS

```bash
cryptsetup luksFormat --type luks2 /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 cryptroot
```

## Btrfs

```bash
mkfs.btrfs -L NixOS /dev/mapper/cryptroot
```

## Subvolume Oluşturma

```bash
mount /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots

umount /mnt
```

## Mount İşlemleri

```bash
mount -o subvol=@,compress=zstd:1,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{home,nix,var/log,.snapshots,boot}

mount -o subvol=@home,compress=zstd:1,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/home

mount -o subvol=@nix,noatime,nodatacow,ssd,discard=async /dev/mapper/cryptroot /mnt/nix

mount -o subvol=@log,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/var/log

mount -o subvol=@snapshots,compress=zstd:1,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/.snapshots

mount /dev/nvme0n1p1 /mnt/boot
```

## Swap (Opsiyonel)

```bash
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2
```

---

# ⚙️ Adım 4 — NixOS Config Oluşturma

```bash
nixos-generate-config --root /mnt
```

Oluşan dosya:

```text
/mnt/etc/nixos/hardware-configuration.nix
```

Bu dosyayı daha sonra kullanacaksınız.

---

# 📦 Adım 5 — Repo Kurulumu

```bash
git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/nixos-config

cd /tmp/nixos-config

chmod +x install.sh

./install.sh
```

Kurulum betiği şunları isteyecektir:

- GPU PCI adresleri
- monitör çıkışı
- Hyprland monitor satırı
- Git kullanıcı bilgileri

---

# 🧩 Adım 6 — hardware-configuration.nix

```bash
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/
```

UUID kontrolü:

```bash
lsblk -f
```

---

# 🔑 Adım 7 — Kullanıcı Parolası

```bash
mkpasswd -m sha-512 | sudo tee /etc/nixos/hashedPassword
```

---

# ⚡ Adım 8 — Sistemi Derleme

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Kurulum tamamlandıktan sonra sistemi yeniden başlatın.

---

# 🖥️ Kurulum Sonrası

## Waydroid

```bash
waydroid init -f
```

## Ollama

```bash
ollama pull llama3
```

## VFIO Logları

```bash
tail -f /var/log/libvirt/vfio.log
```

---

# 🛠️ Sorun Giderme

## Hyprland Açılmazsa

```bash
cat ~/.local/share/hyprland/hyprland.log
```

## VFIO Çalışmazsa

```bash
journalctl -u libvirtd
```

## Wi-Fi Yoksa

```bash
nmtui
```

---

# ⚠️ Önemli Notlar

- Single-GPU passthrough sırasında ekran kararır
- GPU PCI ID’lerinin doğru olduğundan emin olun
- SSH için key-based authentication önerilir
- low_latency_layer tüm Vulkan oyunlarında otomatik olarak etkindir

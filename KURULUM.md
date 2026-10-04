# 🇹🇷 NixOS Hyprland + VFIO Kurulum Rehberi

Bu rehber AMD sistemler için optimize edilmiş **NixOS + LUKS2 + Btrfs + Hyprland + VFIO** kurulum akışıdır.

---

# ⚙️ Ön Gereksinimler

- NixOS 26.05 Live ISO
- UEFI sistem
- AMD Ryzen CPU
- AMD Radeon RX 6000/7000 GPU
- En az 810 GB boş disk (aşağıdaki bölümlendirme 800 GB kullanıyor)

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
| EFI | 1G FAT32 |
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

# home.nix'teki `home.persistence."/nix/persist/home"` (lsfg-vk shader
# önbelleği) bu dizini kalıcı depolama kökü olarak kullanıyor; yoksa Home
# Manager activation bind-mount'u sessizce başarısız olur. @nix alt hacmi
# mount edildikten sonra oluştur (nodatacow, diskte kalıcı).
mkdir -p /mnt/nix/persist/home
# DÜZELTME (2026-10-04): canlı ISO'da `localhost` kullanıcısı yoktur,
# `chown localhost:users` burada hata veriyordu. Kullanıcı ancak
# nixos-install sonrası oluşur; tmpfiles.d kuralları zaten yaratıyor.
# Yalnızca /nix/persist'in doğru sahibi gerekiyorsa:
chown "$(id -un)": /mnt/nix/persist/home 2>/dev/null || true
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

> ℹ️ `hardware-configuration.nix` yukarıdaki `cp` komutuyla **sizin makinenizden
> `nixos-generate-config` ile üretilmiş** olanla değiştirildiği için UUID'ler zaten
> doğrudur; ayrıca elle güncellemeniz gerekmez. Yalnızca `lsblk -f` çıktısı
> beklediğinizle örtüşmüyorsa kontrol edin.
>
> Repo yapısı korunarak kopyalandığı için flake `/mnt/etc/nixos/nixos` altında
> durur → kurulum komutunda `#nixos` öncesi bu dizini göstermelisiniz
> (bir sonraki adıma bakın).

---

# 🔑 8. Şifreler (root + localhost)

```bash
nixos-enter --root /mnt -c 'passwd root'
```

> ⚠️ **`hashedPassword` dosyasını da oluşturun.** `configuration.nix`
> `localhost` kullanıcısını `hashedPasswordFile = "/etc/nixos/hashedPassword"`
> ile tanımlıyor. Bu dosya `.gitignore`'da (bilinçli olarak) tutulmuyor ve
> `nixos-install` sırasında **yoksa hata da vermiyor** — sadece activation'da
> `warning: password file ... does not exist` basıp `/etc/shadow`'a
> `localhost:!:1:::::` yazıyor, yani masaüstü hesabı kilitleniyor ve
> tuigreet ile giriş yapılamıyor. Aşağıdaki komutla oluşturun:
>
> ```bash
> # DÜZELTME (2026-10-04): bu komut /mnt içinde çalıştırıldığı için
> # hedef yol /mnt/etc/nixos DEĞİL, /etc/nixos olmalı. Eski hâliyle
> # hashedPassword hiç oluşmuyor, localhost hesabı kilitli kalıyordu.
> nixos-enter --root /mnt -c 'umask 077; mkdir -p /etc/nixos && mkpasswd --method yescrypt > /etc/nixos/hashedPassword'
> ```
>
> `nixos-enter` `nixos-install` öncesinde genelde "NixOS kurulumu değil" diye
> reddedebilir. O durumda dosyayı ISO tarafından doğrudan yaz:
>
> ```bash
> # 2. adımda mkpasswd çalıştırıp çıktıyı bir değişkene al:
> HASH=$(mkpasswd --method yescrypt)
> # sonra hedefe yaz ve izinleri 600 yap:
> install -d -m 755 /mnt/etc/nixos
> printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
> sudo chmod 600 /mnt/etc/nixos/hashedPassword
> ```
>
> `tee` tek başına 644 açtığı için `chmod 600` adımı atlanmamalı.
>
> `localhost` kullanıcısının şifresiyle (greetd/tuigreet) masaüstüne
> gireceksiniz. Root şifresi ayrıdır ve konsol/acil kip için gereklidir.

> 🔑 **SSH erişimi:** `configuration.nix` `PasswordAuthentication = false`
> ve `authorizedKeys.keys` boş bırakılmış durumda — yani kurulumdan sonra
> uzaktan giriş **kapalıdır**. Siz SSH kullanacaksanız:
> `ssh-keygen -t ed25519 && cat ~/.ssh/id_ed25519.pub` çıktısını
> `configuration.nix` içindeki `users.users.localhost.openssh.authorizedKeys.keys`
> listesine ekleyin, `nixos-rebuild switch` çalıştırın. Kullanmayacaksanız
> `services.openssh.enable = false` yapmak daha temiz.

---

# ⚡ 9. Kurulum

flake.nix repo kökünde değil, `nixos/` alt dizininde olduğu için `#nixos`
öncesindeki yol da buna göre verilmeli:

```bash
# ilk çalıştırmada substituters onayı ister: "y" deyin
nixos-install --flake /mnt/etc/nixos/nixos#nixos --accept-flake-config
```

---

# 🖥️ 9b. VM'yi libvirt'e tanıt (ATLANMA)

> **DÜZELTME (2026-10-04):** bu adım hiçbir dokümanda yoktu. Atlanırsa
> domain tanımsız kalır; `nixos/hooks/qemu` içindeki
> `if [ "$GUEST" != "$TARGET_VM" ]; then exit 0` filtresi (`TARGET_VM="win10"`)
> hiç eşleşmez ve GPU **hiçbir zaman** `vfio-pci`'ye bağlanmaz. Yani tüm
> VFIO sistemi sessizce hiç çalışmaz.

```bash
# vm-xml zaten §7'de repodan /mnt/etc/nixos/vm-xml olarak kopyalandı.
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu
sudo cp /mnt/etc/nixos/vm-xml/win10.xml /var/lib/libvirt/
sudo virsh define /var/lib/libvirt/win10.xml
virsh list --all     # 'win10' → "shut off" olarak görünmeli
```

> ⚠️ **ISO dosyaları:** `virsh start win10` için iki ISO gerekir:
> `Win10_22H2_English_x64v1.iso` ve `virtio-win-*.iso` →
> `sudo cp <iso> /var/lib/libvirt/images/`

> ⚠️ XML'deki disk/NVRAM yolları sabit geliyor. Kendi diskine göre
> düzenlemezsen `virsh start win10` "disk bulunamadı" ile başarısız olur.
>
> ⚠️ **VM'i masaüstü oturumundan başlatmayın.** `hooks/qemu`, GPU'yu bırakmak için
> `loginctl terminate-user <kullanıcı>` çalıştırıyor — yani `virsh start` komutunu
> verdiğiniz oturumun **kendisi** kapanıyor (istemci sonucu gösteremeden ölüyor;
> libvirtd tarafındaki iş devam ediyor). İki güvenli yol:
> ```bash
> # 1) ayrı TTY'den (Ctrl+Alt+F3)
> virsh start win10
>
> # 2) oturumdan bağımsız transient unit
> systemd-run --scope --unit=vmstart virsh start win10
> ```
>
> Doğrulama: `sudo virsh dominfo win10` → ad, UUID ve PCI hostdev'ler görünmeli.
> Hook'un çalıştığını `sudo journalctl -u libvirtd -f` ve
> `sudo tail -f /var/log/libvirt/qemu/win10.log` ile izleyebilirsin.
>
> ⚠️ **Hook logu:** `sudo cat /var/log/libvirt/vfio.log` — GPU'nun gerçekten
> `vfio-pci`'ye bağlandığını, reset durumunu ve (Navi2x'te mümkünse)
> kurtarma adımını burada görürsün. `HOST_USER` değişkenini de dışarıdan
> vermek istersen: `HOST_USER=kullanici sudo virsh start win10`.

---

# 🔄 10. Reboot

```bash
reboot
```

---

# 🧠 Kurulum Sonrası

## Sistem güncelle

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
```

## Yeniden başlat

```bash
sudo reboot
```

> ⚠️ **Reboot zorunludur.** `iommu=pt`, `amd_iommu=on`, `amdgpu.ppfeaturemask`
> gibi kernel parametreleri `switch` ile uygulanmaz; yalnızca yeniden
> başlatınca etkin olur. **Reboot olmadan VFIO testi yapılırsa IOMMU açık
> değildir ve GPU'yu `vfio-pci`'ye bağlamak mümkün olmaz.** Buna karşılık
> hook'un çalıştığını `switch`'ten hemen sonra da doğrulayabilirsiniz.

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

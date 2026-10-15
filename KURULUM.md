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

> ⚠️ **Aşağıdaki komutlar diskin bölüm tablosunu TAMAMEN siler.**
> Yanlış aygıt adı verirseniz mevcut sisteminizi kaybedebilirsiniz.
> Önce bağlı diskleri inceleyin ve hedefin model/seri numarasını doğrulayın:

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
```

> Hedef diski iki kez kontrol edin. Aşağıdaki `/dev/nvme0n1` değerini kendi
> diskinizle değiştirin; devam eden komutları aynı terminal oturumunda çalıştırın.

```bash
DISK=/dev/nvme0n1    # ← BURAYI DEĞİŞTİRİN
# NVMe partition names use p1/p2; SATA/SCSI names look like sda1/sda2.
case "$DISK" in
  *[0-9]) PART_PREFIX="${DISK}p" ;;
  *)      PART_PREFIX="$DISK" ;;
esac
```

| Bölüm | Açıklama |
|------|----------|
| EFI | 1G FAT32 |
| SWAP | 8GB (opsiyonel) |
| LUKS | Ana sistem |

---

## Disk oluşturma

```bash
sudo sgdisk -Z "$DISK"

sudo sgdisk -n 1:0:+1G  -t 1:ef00 -c 1:EFI  "$DISK"
sudo sgdisk -n 2:0:+8G  -t 2:8200 -c 2:SWAP "$DISK"
sudo sgdisk -n 3:0:+800G -t 3:8309 -c 3:LUKS "$DISK"

sudo partprobe "$DISK"
```

---

# 🔒 3. LUKS2 Kurulum

```bash
cryptsetup luksFormat "${PART_PREFIX}3" --type luks2
cryptsetup open "${PART_PREFIX}3" cryptroot
```

---

# 💽 4. Dosya Sistemleri

```bash
mkfs.fat -F32 "${PART_PREFIX}1"
mkswap "${PART_PREFIX}2"
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
# NOTE: @home/.snapshots cannot be created here because @home is not mounted yet.
# The subvolume required by services.snapper.configs.home (SUBVOLUME="/home")
# must be created after @home is mounted below (see Section 6).

umount /mnt
```

---

# 📦 6. Mount İşlemleri

```bash
mount -o subvol=@,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt

mkdir -p /mnt/{boot,home,nix,var/log,.snapshots}

# Create this only AFTER mounting @home (below).

mount -o subvol=@home,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home

# @home is mounted; create and mount the Home Snapper subvolume now.
btrfs subvolume create /mnt/home/.snapshots
mount -o subvol=@home/.snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/home/.snapshots

mount -o subvol=@nix,noatime,nodatacow,ssd,discard=async /dev/mapper/cryptroot /mnt/nix

mount -o subvol=@log,noatime,ssd,discard=async /dev/mapper/cryptroot /mnt/var/log

mount -o subvol=@snapshots,noatime,compress=zstd:1,ssd,discard=async /dev/mapper/cryptroot /mnt/.snapshots


mount "${PART_PREFIX}1" /mnt/boot

swapon "${PART_PREFIX}2"

# Impermanence is not enabled in this configuration; no persistent-home directory is needed.
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
> durur → kurulum komutunda `#nixos` öncesindeki yol bu dizini göstermelisiniz
> (bir sonraki adıma bakın).

---

# ⚠️ 7b. Elle Değiştirilmesi Gereken 5 Değer (ATLANMA)

Bu rehberdeki yol **değerleri sormadan** kurar: `nixos/` klasörü olduğu gibi
kopyalanır. `install.sh`'ı çalıştırmadığınız için `home.nix` içindeki şu değerler
**yer tutucu olarak kalır** ve kurulumdan sonra elle değiştirilmelidir:

| # | Değer | Varsayılan | Sonucu |
|---|-------|-----------|--------|
| 1 | `hyprlandMonitorLine` | `"monitor = ,preferred,auto,1"` | Boş monitör adı, açıkça tanımlanmamış çıkışlara uygulanacak catch-all kuralıdır; workspace aynalama kuralı değildir. Çok monitörde her çıkışa `preferred/auto/1` uygulamak istemiyorsanız gerçek çıkış adını yazın. |
| 2 | `monitorOutput` | `""` (boş) | Yanlış çıktıysa `mpvpaper` duvar kağıdı çalışmaz (oturum açılışında kritik uyarı çıkar) |
| 3 | `gitName` | `"changeme"` | Commit'ler sahte isimle etiketlenir |
| 4 | `gitEmail` | `"you@example.com"` | Commit'ler sahte adresle etiketlenir |
| 5 | `wallpaperVideo` | `~/Downloads/arthur-leywin-….mp4` | Dosya yoksa `Unit.ConditionPathExists` servisi başlatmaz; oturum açılışında kritik uyarı gösterilir |

Mevcut NixOS'u güncelliyorsanız bunların hepsini `install.sh` sizin yerinize
doldurur (monitörü `hyprctl`/`/sys/class/drm`'den okur). Yeni kurulumda elle
yazın:

```bash
# Find the monitor output name.
hyprctl monitors | grep -oPm1 '^Monitor \K\S+'
# Or read it from DRM.
for c in /sys/class/drm/card*-*; do
  [ "$(cat $c/status 2>/dev/null)" = connected ] && basename $c | sed 's/card[0-9]*-//'
done
```

Ardından `/etc/nixos/nixos/home.nix` dosyasının en üstündeki `let` bloğunu
düzenleyin (satır ~4-12):

```nix
  gitName            = "Adınız";
  gitEmail           = "siz@ornek.com";
  monitorOutput      = "DP-1";                              # Output name found above
  hyprlandMonitorLine = "monitor = DP-1,preferred,auto,1";  # Use an explicit output name
  wallpaperVideo     = "${config.home.homeDirectory}/Downloads/duvar-kagidi.mp4";
```

> `hyprlandMonitorLine`'daki boş monitör adı bir catch-all kuralıdır; tek başına
> workspace'leri aynalamaz. Yine de manuel kurulumda hangi çıkışlara kural
> uygulanacağı açık olsun diye `DP-1` gibi gerçek monitör adını kullanın.

### `hyprland.lua` gölgelemesi hakkında

Bu config `.conf` kullanıyor. Hyprland 0.56.2 bir `~/.config/hypr/hyprland.lua`
bulursa onu tercih eder ve `.conf`'i **sessizce tamamen yok sayar** — hata yok,
uyarı yok, masaüstü Hyprland'ın varsayılanına döner.

`home.nix` buna karşı `HYPRLAND_CONFIG` değerini oturum ortamına sabit olarak
yazıyor, bu yüzden **bu kurulumda gölgeleme gerçekleşemez**. Ek olarak WuWa
ekran-okuma bölgeleri `wuwa-auto.sh` içinde artık ekran çözünürlüğüne göre
doğrulanıyor; sığmıyorsa döngüye girmeden uyarı veriyor.

Kontrol (kurulumdan sonra bir kez):

```bash
echo "$HYPRLAND_CONFIG"   # /home/localhost/.config/hypr/hyprland.conf
hyprctl configversion
```

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
> # The live ISO writes into the installed system mounted at /mnt.
> # Therefore, the target file must be /mnt/etc/nixos/hashedPassword.
> HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
> install -d -m 755 /mnt/etc/nixos
> printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
> sudo chmod 600 /mnt/etc/nixos/hashedPassword
> ```
>
> `nixos-enter` `nixos-install` öncesinde genelde "NixOS kurulumu değil" diye
> reddedebilir. O durumda dosyayı ISO tarafından doğrudan yaz:
>
> ```bash
> # Run mkpasswd from a temporary environment and capture its output:
> HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
> # Write the hash to the target system and restrict its permissions:
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
# On the first run, review and accept the configured binary cache if trusted.
nixos-install --flake /mnt/etc/nixos/nixos#nixos --accept-flake-config
```

> **CachyOS kernel cache:** the flake now selects the upstream `release` branch
> and pinned overlay. Before the first build, refresh only this input so the lock
> file points to a revision published to the binary cache:
>
> ```bash
> cd /mnt/etc/nixos/nixos
> nix flake lock --update-input cachyos-kernel
> ```
>
> If the cache is unavailable or the kernel derivation does not match, Nix may
> still attempt a local BORE-LTO build. Do not treat a successful evaluation as
> proof that the kernel will download from cache; inspect the build log.


---

> ⚠️ **VM hazırlığı:** XML ve qcow2 dosyaları kurulum sonrası ilk açılışta oluşturulacak — §10b'ye bakın.

---

# 🔄 10. Reboot

```bash
reboot
```

---

# 🖥️ 10b. VM'yi libvirt'e tanıt (ilk reboot sonrası)

> **DÜZELTME (2026-10-04):** bu adım hiçbir dokümanda yoktu. Atlanırsa
> domain tanımsız kalır; `nixos/hooks/qemu` içindeki
> `if [ "$GUEST" != "$TARGET_VM" ]; then exit 0` filtresi (`TARGET_VM="win10"`)
> hiç eşleşmez ve GPU **hiçbir zaman** `vfio-pci`'ye bağlanmaz. Yani tüm
> VFIO sistemi sessizce hiç çalışmaz.

```bash
# Run these commands after the first reboot, not from the live ISO.
# The source XML is at /etc/nixos/vm-xml/win10.xml on the target system.
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu

# Create the qcow2 disk referenced by the XML. Do not overwrite an existing disk.
if [ ! -f /var/lib/libvirt/images/win10new.qcow2 ]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G
else
  echo "Mevcut VM diski korunuyor: /var/lib/libvirt/images/win10new.qcow2"
fi
# qemu.runAsRoot = false, so set the disk owner and mode explicitly.
sudo chown qemu-libvirtd:qemu-libvirtd /var/lib/libvirt/images/win10new.qcow2
sudo chmod 0660 /var/lib/libvirt/images/win10new.qcow2

# If install.sh was not run, copy the source XML. If it was run,
# /var/lib/libvirt/win10.xml may already contain synchronized PCI addresses;
# do not overwrite an existing deployed file with the source template.
if [ ! -f /var/lib/libvirt/win10.xml ]; then
  sudo cp /etc/nixos/vm-xml/win10.xml /var/lib/libvirt/
else
  echo "Mevcut XML korunuyor; PCI adreslerinin GPU hook'u ile eşleştiğini doğrula."
fi

sudo virsh define /var/lib/libvirt/win10.xml
sudo virsh list --all     # 'win10' → "shut off" olarak görünmeli
```

### İlk başlatmada geçici görüntü kanalı (isteğe bağlı tanılama)

Üretim XML'i `<video><model type="none"/></video>` kullandığı için VNC konsolu
sunmaz. İlk başlatmada hata ayıklamak gerekirse depo kök dizininde aşağıdaki
komutlarla **dağıtılmış ve PCI adresleri senkronize edilmiş XML'in ayrı kopyasını**
üretin. Ana `/var/lib/libvirt/win10.xml` dosyası değiştirilmez:

```bash
sudo python3 scripts/prepare-vm-diagnostic.py \
  --input /var/lib/libvirt/win10.xml \
  --output /var/lib/libvirt/win10-diagnostic.xml
sudo virsh define /var/lib/libvirt/win10-diagnostic.xml
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

Hook, `localhost` kullanıcısının oturumlarını ve seat0/VT'leri kapatabileceği için
normal shell'den VM başlatmayın; `systemd-run` sistem yöneticisi tarafından başlatılan
bağımsız hizmet kullanır. Başka bir oturumdan sonucu ve VNC ekranını kontrol edin:

```bash
sudo journalctl -u vmstart.service -b --no-pager
sudo virsh vncdisplay win10
```

VNC yalnızca `127.0.0.1` adresinde dinler. Test bitince VM'i kapatıp üretim XML'ine
geri dönün: `sudo virsh define /var/lib/libvirt/win10.xml`. Bu tanılama yalnızca
başlangıç/teşhis içindir; oyun için kalıcı çözüm değildir.

> ⚠️ **ISO dosyaları:** `virsh start win10` için iki ISO gerekir:
> `Win10_22H2_English_x64v1.iso` ve `virtio-win-0.1.285.iso` →
> `sudo cp <iso> /var/lib/libvirt/images/`
>
> ⚠️ **XML'deki PCI adresleri:** `install.sh`'ı çalıştırmadıysanız `win10.xml`
> içindeki `<hostdev>` kaynak adresleri depodaki varsayılan
> (`0000:0b:00.0` / `.1`) olarak kalır. `lspci` çıktınla eşleşmiyorsa elle
> düzenleyin — aksi halde hook yeni adrese, libvirt eskisine bakar ve
> "device not found" alırsınız.

> ⚠️ XML'deki disk/NVRAM yolları sabit geliyor. Kendi diskine göre
> düzenlemezsen `virsh start win10` "disk bulunamadı" ile başarısız olur.
>
> ⚠️ **VM'i normal shell'den başlatmayın.** Hook `loginctl terminate-user` ile
> `localhost` kullanıcısının oturumlarını, `loginctl terminate-seat seat0` ile yerel
> VT/greeter oturumlarını sonlandırabilir. Ayrı TTY de aynı kullanıcı/seat kapsamındaysa
> kapanabilir; sistem yöneticisinin başlattığı detached unit kullanın:
> ```bash
> sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
> sudo journalctl -u vmstart.service -b --no-pager
> ```
>
> Doğrulama: `sudo virsh dominfo win10` → ad, UUID ve PCI hostdev'ler görünmeli.
> Hook'un çalıştığını `sudo journalctl -u libvirtd -f` ve
> `sudo tail -f /var/log/libvirt/qemu/win10.log` ile izleyebilirsin.
>
> ⚠️ **Hook logu:** `sudo cat /var/log/libvirt/vfio.log` — GPU'nun gerçekten
> `vfio-pci`'ye bağlandığını, reset durumunu ve (Navi2x'te mümkünse)
> kurtarma adımını burada görürsün.
>
> **Çok kullanıcılı sistemlerde `HOST_USER`:** hook, oturumu kapatmak için
> `loginctl terminate-user "${HOST_USER:-localhost}"` çalıştırır (bkz.
> `nixos/hooks/qemu`). Varsayılan `localhost`, bu config'in kullanıcı adıdır
> ve tek kullanıcılı kurulumlar için doğrudur.
>
> ⚠️ **DÜZELTME (2026-10-06):** burada önce
> `HOST_USER=kullanici sudo virsh start win10` yazıyordu. Bu **çalışmaz**:
> hook'u **libvirtd** (uzun ömürlü bir systemd servisi) çalıştırır, `virsh`
> istemcisinin ortamını **miras almaz**; ayrıca aradaki `sudo` da `env_reset`
> ile ortamı zaten temizler. `HOST_USER` config'in hiçbir yerinde tanımlı
> değildir, dolayısıyla hook her zaman `localhost`'u kullanır.
>
> Gerçekten farklı bir kullanıcıyı hedeflemek istiyorsanız tek yol
> NixOS modülünde hook'a ortam vermektir — `configuration.nix` içinde
> `virtualisation.libvirtd.hooks.qemu.vfio` tanımına bir `environment`
> seçeneği ekleyin (bkz. `nixos/configuration.nix` → `vfioHook`).

---

# 🧠 Kurulum Sonrası

## Sistem güncelle

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
```

## WuWa yerel Gemma modeli (isteğe bağlı, büyük indirme)

Model otomatik indirilmez. WuWa OCR otomatik çevirisini ilk kez kullanmadan önce:

```bash
sudo systemctl start wuwa-gemma-init
sudo systemctl status wuwa-gemma-init --no-pager
```

Servis başarılı bitip `wuwa-gemma` modeli Ollama'da göründükten sonra OCR betiğini
başlatın. Model yoksa betik artık uyarı gösterip çıkar.

## Yeniden başlat

```bash
sudo reboot
```

> ⚠️ Kernel parametreleri ve initrd/VFIO modül değişiklikleri için yeniden
> başlatma gerekebilir. Bu, IOMMU'nun etkin olduğunu tek başına kanıtlamaz.
> `dmesg | grep -Ei "AMD-Vi|IOMMU"` ve `/sys/kernel/iommu_groups/` ile kontrol edin;
> BIOS/UEFI ayarlarında IOMMU/AMD-Vi etkin olmalıdır. Hook'un çalışmasını
> `switch` sonrasında kontrol etmek, IOMMU'nun etkinliğini doğrulamakla aynı değildir.

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

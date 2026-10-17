# 🇹🇷 NixOS Hyprland + VFIO Kurulum Rehberi

Bu rehber AMD sistemler için optimize edilmiş **NixOS + LUKS2 + Btrfs + Hyprland + VFIO** kurulum akışıdır.

---

# ⚙️ Ön Gereksinimler

- NixOS 26.05 Live ISO
- UEFI sistem
- AMD Ryzen CPU
- AMD Radeon RX 6700 XT (Navi 22) — bu yapılandırmanın referans GPU hedefi. Diğer RX 6000/7000 modelleri; PCI/IOMMU grupları, GPU sıfırlama davranışı ve ROCm ayarları ayrıca doğrulanmadan desteklenmiş sayılmaz.
- En az 810 GiB kapasite (yaklaşık 870 GB ondalık); pratikte 1 TB sınıfı disk önerilir.

---

# 🚀 1. Canlı Ortam

ISO → UEFI başlat

```bash
nmtui
```

Klavyeyi TR yap:

```bash
sudo loadkeys trq
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

# Yalnızca tüm diski kabul et; bölüm aygıtı veya var olmayan bir yol kullanma.
if [ ! -b "$DISK" ]; then
  echo "HATA: $DISK mevcut bir blok aygıtı değil." >&2
  exit 1
fi
DISK_TYPE=$(lsblk -dnro TYPE "$DISK") || exit 1
if [ "$DISK_TYPE" != "disk" ]; then
  echo "HATA: $DISK bir disk aygıtı değil (tür: $DISK_TYPE)." >&2
  exit 1
fi

# Hedef disk veya alt bölümlerinden biri bağlıysa devam etme.
if lsblk -nrpo MOUNTPOINTS "$DISK" | grep -qE '[^[:space:]]'; then
  echo "HATA: $DISK veya bölümlerinden biri bağlı. Önce doğru diski doğrula ve bağlantıları kaldır." >&2
  exit 1
fi

# sgdisk'teki G birimi GiB'dir. Bölümler toplam 809 GiB ayırır.
MIN_DISK_BYTES=$((810 * 1024 * 1024 * 1024))
DISK_BYTES=$(sudo blockdev --getsize64 "$DISK") || { echo "HATA: Disk kapasitesi okunamadı." >&2; exit 1; }
if [ "$DISK_BYTES" -lt "$MIN_DISK_BYTES" ]; then
  printf 'HATA: Disk kapasitesi yetersiz (%s bayt); en az 810 GiB (%s bayt) gerekiyor.\n' \
    "$DISK_BYTES" "$MIN_DISK_BYTES" >&2
  exit 1
fi
printf 'Disk kapasitesi kontrolü geçti: %s bayt (asgari 810 GiB).\n' "$DISK_BYTES"

# NVMe disk bölümleri p1/p2 biçiminde, SATA/SCSI ise sda1/sda2 biçimindedir.
case "$DISK" in
  *[0-9]) PART_PREFIX="${DISK}p" ;;
  *)      PART_PREFIX="$DISK" ;;
esac
```

| Bölüm | Açıklama |
|------|----------|
| EFI | 1 GiB FAT32 |
| SWAP | 8 GiB (zorunlu; aşağıdaki komutlar bu bölüm düzenini varsayar) |
| LUKS | 800 GiB ana sistem |

---

## Disk oluşturma

> `sgdisk` komutlarındaki `G` birimi GiB anlamına gelir. Aşağıdaki bölümler toplam 809 GiB ayırır.
> Kapasite ve bağlı bölüm kontrolleri başarılı olsa bile, `sgdisk -Z` mevcut bölüm tablosunu geri alınamaz biçimde siler; model/seri numarasını son kez doğrulayın.

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
sudo cryptsetup luksFormat "${PART_PREFIX}3" --type luks2
sudo cryptsetup open "${PART_PREFIX}3" cryptroot
```

---

# 💽 4. Dosya Sistemleri

```bash
sudo mkfs.fat -F32 "${PART_PREFIX}1"
sudo mkswap "${PART_PREFIX}2"
sudo mkfs.btrfs -L nixos /dev/mapper/cryptroot
```

---

# 🌳 5. Btrfs Subvolumes

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

# 📦 6. Mount İşlemleri

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

# 🧠 7. Repo Kurulumu (DOĞRU YÖNTEM)

`nixos-generate-config` zaten `/mnt/etc/nixos/configuration.nix` ve
`hardware-configuration.nix` dosyalarını oluşturur — bu yüzden repo'yu
doğrudan `/mnt/etc/nixos`'a klonlamaya çalışmak "already exists and is
not an empty directory" hatası verir. Önce ayrı bir dizine klonlayın,
sadece donanıma özel dosyayı (`hardware-configuration.nix`) oradan
alın, gerisini repo'nunkiyle değiştirin:

```bash
sudo nixos-generate-config --root /mnt

git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/hardware-configuration.nix

# Keep the generated files as a backup before replacing the install tree.
sudo mv /mnt/etc/nixos /mnt/etc/nixos-generated-backup
sudo mkdir -p /mnt/etc/nixos
sudo cp -r /tmp/repo/. /mnt/etc/nixos/
```

> ℹ️ `hardware-configuration.nix` yukarıdaki `cp` komutuyla **sizin makinenizden
> `nixos-generate-config` ile üretilmiş** olanla değiştirildiği için UUID'ler zaten
> doğrudur; ayrıca elle güncellemeniz gerekmez. Yalnızca `lsblk -f` çıktısı
> beklediğinizle örtüşmüyorsa kontrol edin.
>
> **Disk swap şifrelemesi:** Örnek yapılandırma, swap bölümünü her aktivasyonda
> rastgele anahtarla şifrelemek için `randomEncryption.enable = true;` kullanır.
> `nixos-generate-config` çıktısındaki `swapDevices` girdisinde kendi swap aygıtı
> yolunu koruyun ve `randomEncryption.enable = true;` ayarını aynı girdiye ekleyin.
> Dosyayı `sudoedit /mnt/etc/nixos/nixos/hardware-configuration.nix` ile düzenleyin.
> Referans yapılandırmadaki gibi `priority = 10;` da ekleyebilirsiniz; zram
> önceliği 100 olduğundan zram önce kullanılır. Rastgele anahtarlı swap şifrelemesi
> kalıcı LUKS anahtarı kullanmaz; yeniden başlatma sonrası önceki swap içeriği
> çözülemez.
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

Kurulum öncesinde hedef sistem `/mnt` altındayken, `/mnt/etc/nixos/nixos/home.nix`
dosyasının en üstündeki `let` bloğunu düzenleyin (satır ~4-12):

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

`configuration.nix`, `localhost` kullanıcısının parolasını
`hashedPasswordFile = "/etc/nixos/hashedPassword"` üzerinden okur. Temiz kurulumda
bu dosyayı hedef sistemin kök dizinine, yani `/mnt/etc/nixos/hashedPassword`
yoluna kurulumdan **önce** yazın. Dosya mevcut ve geçerli bir hash içeriyorsa
üzerine yazmayın; eksik veya boşsa aşağıdaki komut yeni bir hash oluşturur:

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

> `tee` tek başına daha gevşek izinlerle dosya oluşturabilir; bu nedenle sahiplik
> ve `0600` izin adımlarını atlamayın. `nix-shell -p whois` geçici olarak
> `mkpasswd` sağlar; hash komutu parola girişini etkileşimli biçimde ister.
>
> `localhost` parolası Hyprland/tuigreet masaüstü oturumu içindir. Root parolası
> ayrıdır ve konsol/acil kip erişiminde kullanılır; root parolasını kurulum
> başarıyla tamamlandıktan sonra ayarlayın (§9).

> 🔑 **SSH erişimi:** SSH sunucusu TCP 22 üzerinden açıktır; güvenlik duvarı da bu
> porta izin verir. Parola ile giriş yalnızca `localhost` kullanıcısına açıktır,
> root SSH girişi kapalıdır ve Fail2ban başarısız girişleri izler. Güçlü ve benzersiz
> parola kullanın; SSH'yi yalnızca güvendiğiniz ağlarda erişilebilir tutun. Başka bir
> cihazdan `ssh localhost@<sunucu-ip>` ile bağlanın; sunucu IP'sini `ip -br address`
> ile bulabilirsiniz. Daha güvenli anahtar girişi için `ssh-keygen -t ed25519` oluşturup
> `.pub` çıktısını `users.users.localhost.openssh.authorizedKeys.keys` listesine ekleyin.
> Anahtarın çalıştığını doğruladıktan sonra `PasswordAuthentication = false` yapabilirsiniz.

---

# ⚡ 9. Kurulum

flake.nix repo kökünde değil, `nixos/` alt dizininde olduğu için `#nixos`
öncesindeki yol da buna göre verilmeli:

```bash
# On the first run, review and accept the configured binary cache if trusted.
sudo nixos-install --flake /mnt/etc/nixos/nixos#nixos
```

Kurulum başarıyla tamamlandıktan sonra hedef sistem hâlâ `/mnt` altında bağlıyken
root parolasını ayarlayın veya güncelleyin. `nixos-enter` komutu, kurulum
başarıyla tamamlanmadan çalıştırılırsa hedef sistemi tanımayı reddedebilir:

```bash
sudo nixos-enter --root /mnt -c 'passwd root'
```

> **Önemli:** Aşağıdaki `/etc/nixos/nixos` komutları ilk yeniden başlatmadan sonra
> kurulu sistemde çalıştırılmalıdır. Hâlâ Live ISO içindeyseniz bu komutları çalıştırmayın;
> hedef sistem `/mnt` altındadır. İlk kurulumdan önce yeni kernel seçmek istiyorsanız,
> `nixos-install` komutundan önce aynı işlemi `/mnt/etc/nixos/nixos` yoluyla yapın.
>
> **Kernel sürümünü güncelleme:** `flake.nix`, CachyOS upstream `release` kanalındaki
> `linuxPackages-cachyos-rt-bore-lto` paketini kullanır; sürüm numarası dosyaya sabit
> yazılmaz. Bu arşivin kilidi `873c5a2a40575b880a962aaade19afbb572adf92` revizyonunu
> (Linux 7.2.9) seçer; gelecek sürümlerde gerçek revizyon için `flake.lock` dosyasını
> kontrol edin. Kilit dosyası tekrarlanabilirlik sağlar, kalıcı bir sürüm kısıtlaması değildir.
> Yeni upstream kernel yayımlandığında mevcut kilidi yedekleyin, CachyOS girdisini güncelleyin
> ve değişikliği inceleyin:
>
> ```bash
> sudo cp /etc/nixos/nixos/flake.lock /tmp/flake.lock.before-cachyos-update
> sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel
> sudo diff -u /tmp/flake.lock.before-cachyos-update /etc/nixos/nixos/flake.lock || test "$?" -eq 1
> ```
>
> `diff` kodu `1`, dosyalar arasında fark bulunduğunu gösterir; `2` ise komut hatasıdır.
> Nix cache ayarlarını sorarsa URL ve public key'i inceleyip yalnızca güvendiğinizde
> kabul edin; `--accept-flake-config` seçeneğini kontrolü atlamak için kullanmayın.
> Fish `nup` kısayolu aynı hedefli güncellemeyi herhangi bir dizinden yapar ve ayarları
> otomatik kabul etmez. `dry-activate` derlemesi başarılı olmadan sisteme geçmeyin.
> **RT-Bore-LTO'nun LTO varyantı upstream ikili önbelleğinde yayımlanmıyor**; kernel yerel
> olarak derlenecek, uzun sürebilir veya kaynak/araç zinciri sorunlarıyla başarısız olabilir.
> `overlays.pinned`, kernel ile hedef nixpkgs revizyonunu eşleştirir ama eksik cache çıktısı oluşturmaz.


---

> ⚠️ **VM hazırlığı:** XML ve qcow2 dosyaları kurulum sonrası ilk açılışta oluşturulacak — §10b'ye bakın.

---

# 🔄 10. Reboot

```bash
sudo reboot
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
> ⚠️ **VM'i detached bir systemd unit ile başlatın.** Hook yerel grafik oturumlarını
> `loginctl terminate-seat seat0` ile sonlandırır; SSH oturumunu bilerek kapatmaz.
> GPU aygıtlarını kullanan bir süreç kalırsa hook devam etmek yerine devri iptal edip
> geri alma işlemini dener. Başlatma için:
> ```bash
> sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
> sudo journalctl -u vmstart.service -b --no-pager
> ```
>
> Fiziksel kurtarma TTY'sini yine hazır bulundurun ve VM açılırken ikinci bir cihazdan
> SSH bağlantısının korunduğunu gerçek donanımda test edin.
>
> Doğrulama: `sudo virsh dominfo win10` → ad, UUID ve PCI hostdev'ler görünmeli.
> Hook'un çalıştığını `sudo journalctl -u libvirtd -f` ve
> `sudo tail -f /var/log/libvirt/qemu/win10.log` ile izleyebilirsin.
>
> ⚠️ **Hook logu:** `sudo cat /var/log/libvirt/vfio.log` — GPU'nun gerçekten
> `vfio-pci`'ye bağlandığını, reset durumunu ve (Navi2x'te mümkünse)
> kurtarma adımını burada görürsün.
>
> **Oturum kapsamı:** hook artık `HOST_USER` kullanmaz ve `loginctl terminate-user`
> çağırmaz. Yalnızca `seat0` üzerindeki yerel oturumları kapatır; SSH oturumu korunur.
> GPU kullanım denetimi, arka planda GPU'yu tutan bir işlem kalırsa devri güvenli biçimde
> iptal eder.
>
> Gerçekten farklı bir kullanıcıyı hedeflemek istiyorsanız tek yol
> NixOS modülünde hook'a ortam vermektir — `configuration.nix` içinde
> `virtualisation.libvirtd.hooks.qemu.vfio` tanımına bir `environment`
> seçeneği ekleyin (bkz. `nixos/configuration.nix` → `vfioHook`).

### Önceki kernel ile donanım doğrulaması — 16 Ekim 2026

> **Kapsam: aşağıdaki başarılı sonuç önceki standart BORE-LTO kernel'i içindir; güncel RT-Bore-LTO henüz doğrulanmamıştır.**
>
> Depo sahibinin 2026-10-16 tarihinde bildirdiği gerçek sistem testi, önceki standart BORE-LTO kernel'i içindir: rebuild ve kernel derlemesi tamamlanmış, Windows VM açılıp kapatılmış ve ana sistemin görüntüsü/Hyprland oturumu geri gelmiştir. Bu sonuç yeni seçilen RT-Bore-LTO kernel'ini doğrulamaz; RT-Bore-LTO henüz hedef donanımda build/boot/VM yaşam döngüsü testinden geçmemiştir. Yeni kernel derlemesi tamamlandıktan sonra açılışı, VM açılışını, normal kapatmayı, ekran geri dönüşünü ve ikinci VM açılışını tekrar test edin.

---

# 🧠 Kurulum Sonrası

## Sistem güncelle

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

```bash
sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos
```

## WuWa yerel çeviri modeli (`wuwa-gemma`, Aya Expanse 8B tabanlı; isteğe bağlı)

`wuwa-gemma` Ollama adı, `aya-expanse:8b` modelinden oluşturulan özel bir addır; Gemma model ailesi değildir.
Model servis otomatik olarak başlatılmadığı için WuWa OCR çevirisini ilk kez kullanmadan önce servisi elle başlatın.

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
> BIOS/UEFI ayarlarında IOMMU/AMD-Vi etkin olmalıdır. Kurulum betiği GPU ve ses işlevi
> için IOMMU grubu çözümlenemezse yapılandırma dosyalarını dağıtmadan durur. Bir grupta
> ilgisiz aygıtlar varsa üyeleri inceleyip açıkça onaylamadan devam etmeyin. Hook'un
> `switch` sonrasında çalışması, IOMMU'nun etkinliğini veya izolasyonun güvenli olduğunu
> tek başına kanıtlamaz.

## Log kontrol

```bash
sudo journalctl -u libvirtd
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

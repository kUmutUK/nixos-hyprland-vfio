# NixOS · Hyprland · AMD GPU Passthrough (VFIO)

Tek ekran kartı AMD Radeon'u bir **Windows 10 VM'ine** geçiren, geri kalanı
gaming odaklı Hyprland masaüstü olan, tamamen **flake** tabanlı bir NixOS
kurulumu.

> **Doğrulanan hedef:** AMD Ryzen 5 5600 + AMD Radeon RX 6700 XT (Navi 22), UEFI,
> tek ekran kartı. Diğer RX 6000/7000 modelleri otomatik olarak desteklenmiş sayılmaz;
> PCI/IOMMU grubu, GPU reset davranışı ve ROCm ayarı ayrıca doğrulanmalıdır. NVIDIA
> ve Intel bu yapılandırmanın hedefi değildir.

---

## İçindekiler

- [Ne işe yarar](#ne-işe-yarar)
- [Sorumluluk Reddi](#sorumluluk-reddi)
- [Gereksinimler](#gereksinimler)
- [Kurulum](#kurulum) — *yeni sistem* ve *mevcut NixOS'a geçiş* olarak iki yol
- [VM'i başlatma](#vmi-başlatma)
- [Tuş kısayolları](#tuş-kısayolları)
- [Grafik ve oyun](#grafik-ve-oyun)
- [Bu config'in özel ayarları](#bu-configin-özel-ayarları)
- [Bilinen sınırlar](#bilinen-sınırlar)
- [Depo haritası](#depo-haritası)
- [Doğrulama](#doğrulama)

---

## Ne işe yarar

Oyun ve günlük masaüstü işi aynı makinede. GPU VM'e geçtiğinde:

- Masaüstü oturumu (greetd) durdurulur, GPU `vfio-pci`'ye bind edilir.
- VM kapanınca GPU host'a geri verilir, oturumlar geri açılır.
- Bind başarısız olursa hook **rollback** yapar ve VM'nin açılmasını engeller —
  yarım kalmış (ne host'ta ne guest'te GPU) bir sistem bırakmaz.

GPU'nun host ile VM arasında devri normal VM yaşam döngüsünde hook tarafından
otomatik yönetilir. Ancak ilk kurulumda domain'i `virsh define` ile tanımlamak,
sanal diski ve ISO yollarını hazırlamak ve GPU host'a devredildiğinde kullanılacak
klavye/fare girişini yapılandırmak gerekir. Adımlar için [VM'i başlatma](#vmi-başlatma)
bölümüne bakın.

---

## Sorumluluk Reddi

Bu config **kişisel bir NixOS kurulumudur** ve belirli bir donanım
(AMD Ryzen 5 5600 + AMD RX 6700 XT + tek GPU + UEFI + LUKS2/Btrfs) için
yazılmıştır. Başka bir makinede:

- `hardware-configuration.nix`'teki UUID'ler **yanlışsa sistem açılmaz**
- `sgdisk -Z` komutu **yanlış diski siler** (geri dönüşü yok)
- VFIO hook'u **GPU'yu host'tan alır**, geri gelmezse host grafik oturumu kapanır
- Kernel parametreleri **yanlışsa boot fail olur**

Bu config'i kullanmanın **tüm riski size aittir.** Yazar, bu config'in
neden olduğu veri kaybı, sistem arızası, donanım hasarı veya başka
herhangi bir zarardan **sorumlu tutulamaz.**

Lisans: MIT — bkz. `LICENSE` (yasal olarak "as is", garanti yok).

---

## Gereksinimler

| | |
|---|---|
| **CPU** | AMD Ryzen (desktop). Intel desteklenmiyor — `kvm-amd`, `amd_iommu`, `amd_pstate` sabit kodlanmış. |
| **GPU** | Doğrulama hedefi RX 6700 XT (Navi 22). Ollama için `rocmOverrideGfx = "10.3.0"` kullanılıyor; diğer modellerde aynı değerin uygun olduğu varsayılmamalı. |
| **Firmware** | UEFI zorunlu. BIOS'ta IOMMU **açık** olmalı (`amd_iommu=on` etkinleşmesi için). |
| **Depolama** | ~810 GB boş alan (aşağıdaki bölümlendirmede 1 GiB EFI + 8 GiB swap + 800 GiB LUKS). |
| **Kernel** | CachyOS BORE-LTO paketi flake input'u üzerinden seçiliyor. Gerçek sürüm, kilitli girdi ve güncellenen paketle değişebilir; çalışan sürümü `uname -r` ile kontrol edin. |
| **Disk** | LUKS2 + Btrfs (subvolume'lu) + EFI. Swap LUKS'un **dışında**, açık bölümde. |

> **Çok kartlı sistem uyarısı.** Kurulum betiği IOMMU grubunu denetler. Grubun
> tamamını VM'e veremiyorsanız ek önlemler (ACS override) gerekir; bu config
> tek kartlıdır.

---

## Kurulum

Repo kökü `/etc/nixos/`'a karşılık gelir; **flake `/etc/nixos/nixos` altında**
durur. Bu yüzden tüm komutlarda yol `…/nixos#nixos` biçimindedir.

### **Yol A —** Sıfırdan (yeni kurulum)

Tam rehber: **[`KURULUM.md`](KURULUM.md)** — bölümlendirmeden LUKS'e,
subvolume'lardan `nixos-install`'a kadar adım adım.

Özet akış:

```bash
nixos-generate-config --root /mnt                      # donanım dosyası
git clone https://github.com/kUmutUK/nixos-hyprland-vfio.git /tmp/repo
cp /mnt/etc/nixos/hardware-configuration.nix /tmp/repo/nixos/   # kendi UUID'lerin
rm -rf /mnt/etc/nixos && mkdir -p /mnt/etc/nixos && cp -r /tmp/repo/. /mnt/etc/nixos/
nixos-install --flake /mnt/etc/nixos/nixos#nixos --accept-flake-config
```

Kritik iki nokta:

- **`hardware-configuration.nix` elle doldurulmalı.** Depodaki değerler
  bakımcının kendi makinesine ait. Kurağı dağıtıyorsanız `nixos-generate-config`
  çıktısıyla değiştirin; aksi halde yanlış diski göstermiş olursunuz.
- **`hashedPassword` dosyasını oluşturun.** Yoksa `localhost` hesabı
  `!:1:::::` ile kilitlenir ve tuigreet'ten giriş yapamazsınız:
  ```bash
  HASH=$(nix-shell -p whois --run 'mkpasswd --method yescrypt')
  install -d -m 755 /mnt/etc/nixos
  printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
  sudo chmod 600 /mnt/etc/nixos/hashedPassword
  ```

### **Yol B —** Mevcut NixOS'u bu config'e taşı

```bash
./install.sh
```

Betik GPU/IOMMU tespiti yapar, GPU PCI adreslerini sorup **hem** hook'a
**hem** `win10.xml`'e işler, ayarları `home.nix`'e yazar ve yedek alır.

Elle klonluyorsanız (betiği çalıştırmadan) `home.nix` içindeki **5 değeri elle
doldurmanız gerekir** — `KURULUM.md` §7b'de tablo hâlinde listeli.

### Ortak son adımlar

```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
sudo nixos-rebuild switch     --flake /etc/nixos/nixos#nixos
sudo reboot            # ZORUNLU
```

> 🔴 **Reboot zorunludur.** `iommu=pt`, `amd_iommu=on`,
> `amdgpu.ppfeaturemask` gibi kernel parametreleri `switch` ile uygulanmaz.
> **Reboot etmeden VFIO testi yaparsanız IOMMU açık değildir** ve GPU
> `vfio-pci`'ye bağlanmaz.

### SSH notu

`PasswordAuthentication = false` ve `authorizedKeys` **boş** bırakılmıştır —
kurulumdan sonra uzaktan giriş **kapalıdır**. `configuration.nix` →
`users.users.localhost.openssh.authorizedKeys.keys` listesine kendi
`ed25519` public key'inizi ekleyin. SSH kullanmayacaksanız
`services.openssh.enable = false` yapmak daha temiz.

---

## VM'i başlatma

Önce domain'in libvirt'te tanımlı, sanal diskin mevcut ve ISO yollarının doğru olması gerekir. GPU host'a devredildiğinde masaüstü oturumu duracağı için VM'e giriş aygıtı da önceden hazırlanmalıdır. Bu XML'de varsayılan olarak çalışan bir USB klavye/fare aktarımı tanımlı değildir.

**Yol B — `./install.sh` kullandıysanız:** Betik, ilk rebuild öncesinde VM diski oluşturmuyor.
Önce disk UUID'lerini/parola dosyasını doğrulayın, `nixos-rebuild switch` uygulayın ve yeniden
başlatın. Ardından [`KURULUM.md` §10b](KURULUM.md) bölümündeki disk hazırlama/sahiplik
komutlarını çalıştırın. Betiğin oluşturduğu PCI adresleri senkronize XML'i
`/var/lib/libvirt/win10.xml` konumundadır; disk hazırlandıktan sonra tanımlayın:

```bash
sudo virsh define /var/lib/libvirt/win10.xml
```

**Yol A — Elle kurulum yaptıysanız** (README → Yol A veya KURULUM.md). Bu komutları
yalnızca `nixos-rebuild switch` ve ilk reboot tamamlandıktan sonra çalıştırın:

```bash
# Run after nixos-rebuild switch + reboot, when libvirt and qemu-libvirtd are active.
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu
sudo cp /etc/nixos/vm-xml/win10.xml /var/lib/libvirt/
if [ ! -f /var/lib/libvirt/images/win10new.qcow2 ]; then
  sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G
fi
sudo chown qemu-libvirtd:qemu-libvirtd /var/lib/libvirt/images/win10new.qcow2
sudo chmod 0660 /var/lib/libvirt/images/win10new.qcow2
sudo virsh define /var/lib/libvirt/win10.xml
```

> Sıfırdan kurulum sırasında XML `/mnt/etc/nixos/vm-xml/win10.xml` altındadır;
> ilk reboot sonrası hedef sistemde `/etc/nixos/vm-xml/win10.xml` olur. Tam VM hazırlığı
> [`KURULUM.md` §10b](KURULUM.md) bölümündedir. Ayrıca `install.sh`'ı çalıştırmadıysanız
> XML'deki `<hostdev>` PCI adresleri depodaki varsayılandır — `lspci` ile
> eşleştirin (`nixos/hooks/qemu` içindeki `GPU_PCI` / `GPU_AUDIO` ile aynı olmalı).
>
> **VM'e klavye/fare hazırlığı:** Kendi giriş aygıtınızın VID:PID'sini `lsusb` ile bulun.
> `virsh define` komutuna vereceğiniz XML dosyasındaki (`/var/lib/libvirt/win10.xml`)
> yorumlu USB `<hostdev>` örneğini açıp kendi aygıtınıza göre düzenleyin. Kaynak dosyayı
> (`vm-xml/win10.xml` veya `/etc/nixos/vm-xml/win10.xml`) düzenlediyseniz değişikliği
> `/var/lib/libvirt/win10.xml` dosyasına da kopyalayın. Bakımcının cihaz kimliklerini olduğu
> gibi kopyalamayın. Ardından `sudo virsh define /var/lib/libvirt/win10.xml` komutunu
> çalıştırın. Klavye/fareyi ayrı bir USB denetleyicisiyle geçiriyorsanız tek tek aygıt
> geçirmek yerine o yöntemin kurulumunu kullanın. Host oturumu durduğunda giriş
> yapabileceğinizi önceden doğrulayın.

```bash
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

Bu komut kullanıcı oturumu kapansa da systemd tarafından sürdürülür. İlk açılışta
boot ekranını gözlemlemek gerekiyorsa aşağıdaki geçici VNC tanılama adımlarını önce uygulayın.

### İlk açılış için geçici VNC teşhis kanalı

Üretim XML'inde grafik konsolun olmaması, GPU passthrough tasarımının parçasıdır.
İlk testte boot katmanını gözlemlemek için üretim XML'ini değiştirmeden ayrı bir
kopya üretin; böylece install.sh'ın yazdığı gerçek PCI adresleri korunur:

```bash
sudo python3 scripts/prepare-vm-diagnostic.py \
  --input /var/lib/libvirt/win10.xml \
  --output /var/lib/libvirt/win10-diagnostic.xml
sudo virsh define /var/lib/libvirt/win10-diagnostic.xml
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
```

**Dikkat:** Tanılama XML'inin içindeki domain adı da `win10` olduğu için `virsh define`
mevcut `win10` tanımını geçici olarak değiştirir; ikinci bir `win10-diagnostic` VM'i yaratmaz.
Bu adımı yalnızca tanılama gerektiğinde uygulayın. Test sonrası VM'i kapatın ve üretim XML'ini
yeniden tanımlayın (aşağıdaki geri dönüş komutu).

Hook, `loginctl terminate-user` ile `localhost` hesabının oturumlarını ve
`loginctl terminate-seat seat0` ile yerel VT/greeter oturumlarını sonlandırabilir;
bu nedenle `virsh start` komutunu normal shell'inizden çalıştırmayın. Sistem
systemd'si tarafından başlatılan unit kullanıcı oturumu kapansa da devam eder.
Komut sonrası ayrı bir oturumdan kontrol edin:

```bash
sudo journalctl -u vmstart.service -b --no-pager
sudo virsh vncdisplay win10
```

VNC yalnızca `127.0.0.1` üzerinde dinler. Uzak istemciden görüntü gerekiyorsa
SSH tüneli kullanın; VNC'yi tüm ağ arayüzlerine açmayın. Test bitince VM'i kapatıp
üretim XML'ine geri dönün: `sudo virsh define /var/lib/libvirt/win10.xml`.

`prepare-vm-diagnostic.py`, yalnızca belirtilen XML'in ayrı kopyasını üretir; diski,
üretim XML'ini veya NixOS yapılandırmasını değiştirmez. VM çalışırken host'ta
normal grafik oturumu bulunmaz; bu, tek kartlı geçiş tasarımının doğal sonucudur.

Gerekli iki ISO'yu `/var/lib/libvirt/images/` altına kopyalayın:
`Win10_22H2_English_x64v1.iso` ve `virtio-win-*.iso`.

Hook'un ne yaptığını izlemek için:

```bash
sudo cat /var/log/libvirt/vfio.log      # bağlama, reset, kurtarma adımları
sudo journalctl -u libvirtd -f
```

---

## Tuş kısayolları

`SUPER` = Ana Mod (`$mainMod`, fiziksel olarak **Super** tuşu).

### Uygulamalar

| Tuş | İşlev |
|---|---|
| `SUPER` + `Return` / `SUPER` + `C` | kitty terminal |
| `SUPER` + `A` | rofi uygulama başlatıcı |
| `SUPER` + `S` / `SHIFT S` / `CTRL S` | pypr scratchpad: terminal / müzik / dosya yöneticisi |
| `SUPER` + `Q` | aktif pencereyi kapat |
| `SUPER` + `F` | tam ekran |
| `SUPER` + `V` | yüzen pencere |
| `SUPER` + `W` | waypaper (statik duvar kâğıdı) † |
| `SUPER` + `Escape` | hyprlock (kilitle) |
| `SUPER` + `SHIFT E` | oturumu kapat |
| `SUPER` + `SHIFT C` | hyprpicker renk seçici |
| `SUPER` + `G` | pencere grubu |
| `SUPER` + `Tab` | önceki çalışma alanı |

### Pencere yönetimi

| Tuş | İşlev |
|---|---|
| `SUPER` + `←↑↓→` veya `H J K L` | oda değiştir |
| `SUPER` + `SHIFT` + `←↑↓→` / `H J K L` | pencereyi taşı |
| `SUPER` + `CTRL` + `←↑↓→` / `H J K L` | boyutlandır |
| `SUPER` + tekerlek ↓ / ↑ | sonraki / önceki pencene geç |
| `SUPER` + sol tuş (basılı tutup sürükle) | pencereyi sürükle |
| `SUPER` + sağ tuş (basılı tutup sürükle) | boyutlandır |

> Tekerlek binding'leri `SUPER` ile **fare tekerleğinde** çalışır; dokunmatik
> panelde `onAxisEvent` tetiklenmediği için karşılığı yoktur.

### Çalışma alanları

`SUPER` + `1…9` → workspace'e geç · `SUPER` + `0` → workspace 10
`SUPER` + `SHIFT` + `1…0` → pencereyi workspace'e taşı

### Ekran görüntüsü ve çeviri

| Tuş | İşlev |
|---|---|
| `SUPER` + `P` | bölge seç → panoya kopyala |
| `SUPER` + `SHIFT P` | bölge seç → `satty` ile düzenle → panoya |
| `SUPER` + `Y` | WuWa AI otomatik çeviri toggle'ı |
| `SUPER` + `SHIFT T` | tek seferlik OCR + çeviri (Türkçe) |
| `SUPER` + `ALT T` | fare seçimini otomatik çevir toggle'ı |

> ⚠️ `auto-translate.sh` ve `SUPER`+`SHIFT`+`T` komutu `translate-shell`
> (`trans`) kullanır ve varsayılan olarak Google Translate backend'ine bağlanır.
> Fareyle seçtiğiniz metin çeviri için ağa gönderilir; hassas metinlerde
> kullanmayın. Çevirinin yerel kalmasını istiyorsanız `trans` çağrısını Ollama
> tabanlı yerel bir çeviri akışıyla değiştirin.

**WuWa OCR'nin yerel Gemma yedeği:** büyük model indirmesi bilerek otomatik
başlatılmaz. İlk kullanım öncesi bir kez çalıştırın ve tamamlanmasını bekleyin:

```bash
sudo systemctl start wuwa-gemma-init
sudo systemctl status wuwa-gemma-init --no-pager
```

`wuwa-auto.sh` artık `wuwa-gemma` modeli API'de yoksa açık bildirim vererek
başlamadan çıkar; `null` sonucu OCR metni olarak işlemez.

Ses seviyesi için `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` çalışır.

> † **`SUPER`+`W` statik duvar kâğıdı içindir, canlı duvar kâğıdı değil.** Masaüstünde
> asıl olarak `mpvpaper` (video) çalışıyor; `mpvpaper.service` + `mpvpaper-watchdog`
> onu yönetiyor. `waypaper`'ın kendi yapılandırılmış duvar kağıdı yok, dolayısıyla
> bu tuş pratikte boş bir seçici açıyor ve mpvpaper'a dokunmuyor. Binding'i
> tamamen kaldırmak isterseniz: `nixos/home.nix` → `bind = $mainMod, W, …` satırı.
> İki aracı birlikte kullanacaksanız sıralamanın fark ettiğini bilin — mpvpaper
> video layer'ı, waypaper ise arka plan resmini yazar.

---

## Grafik ve oyun

| Bileşen | Ne yapar |
|---|---|
| **RADV** | Vulkan sürücüsü. `AMD_VULKAN_ICD=RADV`, `RADV_PERFTEST=gpl`. |
| **lsfg-vk** | Vulkan katmanı — kare üretimi (lossless scaling tabanlı). Oyun başına çarpanlar `~/.config/lsfg-vk/conf.toml` içinde. |
| **low_latency_layer** | Vulkan katmanı — `VK_AMD_anti_lag`, yani NVIDIA Reflex karşılığı. `LOW_LATENCY_LAYER_REFLEX=1` ile etkin. |
| **GameMode** | Oyun başlarken `renice -10`, `ioprio 0`, `amd_performance_level=high`. |
| **Gamescope** | Oyun penceresine tam ekran + düşük gecikme kuralı (`windowrule`). |
| **MangoHud** | `~/.config/MangoHud/MangoHud.conf` — FPS/frametime/GPU-CPU sıcaklık. |
| **Ananicy-cpp** | Öncelik kuralları (CachyOS rules). |
| **power-profiles-daemon** | CPU governor. |
| **Steam / Proton / Wine** | `steam`, `protonup-qt`, `wine`, `winetricks`, `heroic`. |

İki Vulkan katmanı da `enable_environment` içermez; ikisi de varsayılan olarak
açıktır. Doğrulama:

```bash
VK_LOADER_DEBUG=layer vulkaninfo 2>&1 | grep -iE "korthos|lsl"
```

> **Guest tarafı ayarlı.** `vm-xml/win10.xml` bir **Windows 10** domain'idir;
> `kvm.ignore_msrs=1` Windows 10'un bozuk MSR raporlamasını bastırmak için var.
> Linux guest kullanırsanız gereksizdir, çıkarın.

---

## Bu config'in özel ayarları

Bunlar "NixOS'un default'undan farklı ve bilinçli" seçimlerdir:

| Ayar | Neden |
|---|---|
| `systemd-boot` | UEFI zorunlu; GRUB yok. |
| `virtualisation.libvirtd.hooks.qemu.vfio` | libvirt hook'u yalnızca `/var/lib/libvirt/hooks/qemu.d/` altını tarar — `/etc/libvirt/hooks` **okunmaz**. NixOS'un `environment.etc` ile `/etc`'ye koyması hook'u sessizce ölü bırakırdı. |
| Hook shebang'ı store-path'li | `libvirtd.service`'in PATH'inde bash yok; `#!/usr/bin/env bash` script'i hiç başlatmıyordu. |
| Hook PATH'i zorlanıyor | `ls` (findutils) ve `sed` (gnused) coreutils'te **değildir**; eksikken `gpu_drm_card()` sessizce hep `card0`'a düşüyordu. |
| `zramSwap.priority = 100` | Disk swap'in `priority = 10`. Yüksek öncelik önce kullanılır — önceki durumda zram hiç devreye girmiyordu (~8 MiB ölçülmüştü). |
| `vm.swappiness = 180` | RAM baskınken agresif temizlemeye izin verir. (Öncelik seçmez, **yazma eğilimini** ayarlar.) Bedeli: major page fault/swap baskısı artabilir; zram dolup disk swap devreye girerse oyun frametime'ı sıçrayabilir. |
| `hypridle` 900 sn → `systemctl suspend` | Suspend öncesi hyprlock **çağrılmaz**: foreground'da bloklar ve arkadaki suspend'e hiç sıra gelmez. Kilit zaten `before_sleep_cmd` ile yapılıyor. |
| `HYPRLAND_CONFIG` aktarımı | Home Manager değişkeni olağan kullanıcı oturumlarını kapsar; greetd/tuigreet bu ortamı garanti etmediğinden `configuration.nix` de aynı yolu dışa aktaran bir sarmalayıcı kullanır. Böylece Hyprland `hyprland.lua` dosyasını `.conf` yerine seçmez. |
| `amd_pstate=active`, `pcie_aspm=off` | `amd_pstate=active` AMD P-State sürücüsünü etkinleştirir. Güncel çekirdeklerde `pcie_aspm=off`, ASPM'yi kapatmaz; firmware'in mevcut ASPM ayarını değiştirmeden bırakır. Bu seçenek tek başına VFIO gecikme kazancı sağlamayı garanti etmez. |
| `nowatchdog`, `nmi_watchdog=0` | Kernel/NMI watchdog tabanlı lockup teşhisini azaltır veya kapatır; düşük jitter tercihi karşılığında kilitlenme teşhis bilgisi kaybolabilir. |
| `usbcore.autosuspend=-1` | USB autosuspend'i tamamen kapatır; bazı cihaz/VM passthrough sorunlarını önleyebilir ama boşta USB güç tüketimini artırır. |
| `kvm.ignore_msrs=1` | Bazı Windows guest MSR erişimlerinin hata üretmesini önler, fakat hatalı/bilinmeyen MSR erişimlerini gizleyebilir. |

**Ayarların sahibi:** üç yazıcı birbiriyle yarışıyor —
`power-profiles-daemon` (CPU governor), `ananicy-cpp` (nice/ioprio) ve
`gamemode` (`renice -10`). ppd yalnız governor'a dokunmalı, ananicy scheduler
otoritesi olmalı. Oyun sırasında gamemode ikisini de ezmekte; bu bilinçli.
Oyun dışında ppd profilini `balanced`'a çekmeniz önerilir.

---

## Bilinen sınırlar

- **Navi 2x GPU reset.** RX 6000 serisi `gnif/vendor-reset`in desteklediği
  "reset bug" listesinde **yok**. VM ikinci kez açılamadığında kart PCIe
  bus'tan düşebilir. Hook'ta sessiz unbind/rebind işe yaramazsa `remove` +
  `rtcwake` + `rescan` kurtarma yolu bulunur; bu yol **varsayılan olarak kapalıdır**.
  Opt-in açmak için `configuration.nix`'e
  `systemd.services.libvirtd.environment.VFIO_ALLOW_SUSPEND_RECOVERY = "1";`
  ekleyip sistemi yeniden oluşturun. Bu yol host'u kısa süreliğine askıya alır;
  RTC uyandırma BIOS'ta desteklenmiyorsa kurtarma risklidir. Fallback kapalıyken
  kurtarma başarısız olursa log'u inceleyin ve gerekirse host'u yeniden başlatın.
  Üretim/günlük kullanım öncesi RX 6700 XT ile en az şu döngüyü doğrulayın:
  VM başlat → normal kapat → ikinci kez başlat → host grafik oturumuna dönüş.
  Ayrıca açılışın yarıda kalması ve VM'in zorla kapatılması durumlarını test edin;
  başarılı CI sonucu bu donanım testlerinin yerine geçmez.
- **Host'ta GPU yokken grafik yok.** VM çalışırken yalnızca metin konsolu var.
  Acil kurtarma için `Ctrl+Alt+F2` → `systemctl reboot`.
- **`HOST_USER` sabit.** Hook `localhost`'u sonlandırır. Tek kullanıcılı
  kurulum içindir; `KURULUM.md` §10b'de bu konu ayrıntılı.
- **VM'e giriş cihazı otomatik yapılandırılmıyor.** `vm-xml/win10.xml` içindeki USB hostdev
  yorum satırında; `<graphics>`/VNC/SPICE elemanı da yok. GPU passthrough'tan sonra
  host'ta grafik olmaması beklenir ve host'a bağlı klavye/fare kendiliğinden guest'e
  geçmez. VM'i kontrol edebilmek için kendi USB klavye/farenizi (veya ayrı USB
  denetleyicisini) XML'de açıkça guest'e aktarın. Tek tek cihaz aktarımı için `lsusb`
  çıktısından kendi VID:PID'nizi bulun, yorumlu `<hostdev mode="subsystem" type="usb">`
  örneğini düzenleyin ve domain'i yeniden `virsh define` edin. `managed="yes"`
  kullanıldığında libvirt aygıtı VM için ayırmayı ve kapandığında geri vermeyi yönetir.
  > 💡 `2a7a:8a47` yorumdaki değer bakımcının CASUE klavyesine aittir; aynen kopyalamayın.
  > Klavye/fareyi host'tan devretmeden önce VM açıkken host oturumunun kapanacağını unutmayın.
- **swap şifrelenmemiş.** LUKS dışındaki açık bölümde.
- **CSR (Client-Side Rendering).** Bu bir oyun/gaming config'i; KDE/Wayland
  gibi ağır masaüstü bileşenleri yok.
- **`wuwa-auto.sh` ekran koordinatları.** Varsayılanları 2560×1440'e göre
  yazıldı; başka çözünürlükte ekrana sığmıyorsa döngüye girmeden uyarı
  basar. `WUWA_GEOMETRY_MAIN` / `WUWA_GEOMETRY_CHOICE` ile geçersiz kılınabilir.
  Boşta kaldığında 3 sn → 30 sn arası kademeli bekler, yani gün boyu sürekli
  OCR yapmaz.
- **`assets/` klasörü bu sürümde bilerek kaldırılmıştır.** Etkin Nix/Hyprland yapılandırması bu klasöre başvurmaz; eski `CHANGELOG.md` ve `docs/archive/` içindeki atıflar geçmiş sürümlere aittir.
- **`docs/archive/` arşivdir.** O klasördeki raporlar eski sürümlere karşı
  yazıldı; koda bakarak doğrulama için kullanmayın.

---

## Depo haritası

```
.
├── README.md                     ← bu dosya
├── KURULUM.md                    ← sıfırdan kurulum (yeni sistem)
├── CONTRIBUTING.md               ← katkı akışı + doğrulama komutları
├── CHANGELOG.md                  ← sürüm geçmişi ve düzeltme kayıtları
├── install.sh                    ← mevcut NixOS'a taşıma / güncelleme
├── LICENSE                       ← MIT
│
├── .github/workflows/check.yml   ← CI: shellcheck + gömülü script'ler + nix flake check
├── docs/archive/                 ← eski analiz raporları (arşiv — doğrulama için değil)
├── scripts/
│   ├── extract-embedded-scripts.py   ← home.nix'e gömülü bash'i diske çıkarır (CI için)
│   └── prepare-vm-diagnostic.py      ← ayrı, loopback-only VNC/virtio tanılama XML'i üretir
├── vm-xml/
│   └── win10.xml                 ← libvirt domain tanımı
│
└── nixos/                        ← /etc/nixos'a kopyalanır
    ├── flake.nix                 ← nixosSystem + devShell
    ├── flake.lock                ← kilitli girdiler
    ├── configuration.nix         ← sistem: kernel, VFIO, servisler, paketler
    ├── home.nix                  ← Home Manager: Hyprland, Waybar, kabuk, betikler
    ├── hardware-configuration.nix ← ⚠️ MAKİNEYE ÖZGÜ — başka bir makineye kopyalıyorsanız değiştirin
    └── hooks/qemu                ← libvirt VFIO hook'u (configuration.nix içine gömülür)
```

`nixos/` içinde ikinci bir doğruluk kaynağı yoktur: Hyprland/Hyprlock/Waybar
configleri, pyprland, MangoHud, lsfg-vk ve tüm yardımcı betikler `home.nix`
içinde **inline** tanımlıdır.

---

## Doğrulama

Değişiklikten önce:

```bash
nix develop ./nixos                    # nixfmt, statix, deadnix, shellcheck, jq, pciutils
nixfmt .                               # biçimlendir

shellcheck -S warning install.sh nixos/hooks/qemu
python3 scripts/extract-embedded-scripts.py /tmp/emb | xargs -0 -r -n1 -- shellcheck -S warning

cd nixos && nix flake check --no-build
```

`nix flake check --no-build` yalnızca **değerlendirir**, derlemez. Yanlış yazılmış
bir option adı (`xwaylan.enable` gibi) sessizce merge olup sisteminizi kırmak
yerine burada düşer. Tam doğrulama:

```bash
nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos
```

---

## Lisans

MIT — bkz. [`LICENSE`](LICENSE).

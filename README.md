# NixOS · Hyprland · AMD GPU Passthrough (VFIO)

Tek ekran kartı AMD Radeon'u bir **Windows 10 VM'ine** geçiren, geri kalanı
gaming odaklı Hyprland masaüstü olan, tamamen **flake** tabanlı bir NixOS
kurulumu.

> Hedef donanım: AMD Ryzen (desktop) + AMD Radeon RX 6000/7000 · UEFI ·
> tek ekran kartı. NVIDIA ve Intel için destek yok.

---

## İçindekiler

- [Ne işe yarar](#ne-işe-yarar)
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

Elle yapılan hiçbir şey gerekmez; libvirt her `virsh start`/`virsh destroy`
değerinde hook'u çağırır.

---

## Gereksinimler

| | |
|---|---|
| **CPU** | AMD Ryzen (desktop). Intel desteklenmiyor — `kvm-amd`, `amd_iommu`, `amd_pstate` sabit kodlanmış. |
| **GPU** | AMD Radeon RX 6000/7000 (Navi 22/23). Config'de Ollama için `rocmOverrideGfx = "10.3.0"` yazılı. |
| **Firmware** | UEFI zorunlu. BIOS'ta IOMMU **açık** olmalı (`amd_iommu=on` etkinleşmesi için). |
| **Depolama** | ~810 GB boş alan (aşağıdaki bölümlendirmede 1 GiB EFI + 8 GiB swap + 800 GiB LUKS). |
| **Kernel** | CachyOS BORE 6.18 (önyüklenen flake input'u üzerinden). |
| **Disk** | LUKS2 + Btrfs (subvolume'lu) + EFI. Swap LUKS'un **dışında**, açık bölümde. |

> **Çok kartlı sistem uyarısı.** Kurulum betiği IOMMU grubunu denetler. Grubun
> tamamını VM'e veremiyorsanız ek önlemler (ACS override) gerekir; bu config
> tek kartlıdır.

---

## Kurulum

Repo kökü `/etc/nixos/`'a karşılık gelir; **flake `/etc/nixos/nixos` altında**
durur. Bu yüzden tüm komutlarda yol `…/nixos#nixos` biçimindedir.

### Yol A — Sıfırdan (yeni kurulum)

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
  HASH=$(mkpasswd --method yescrypt)
  install -d -m 755 /mnt/etc/nixos
  printf '%s\n' "$HASH" | sudo tee /mnt/etc/nixos/hashedPassword >/dev/null
  sudo chmod 600 /mnt/etc/nixos/hashedPassword
  ```

### Yol B — Mevcut NixOS'u bu config'e taşı

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

Önce domain'in libvirt'te **tanımlı** olması ve **sanal diskin** var olması gerekir.
Bu iki adım `./install.sh` tarafından yapılır; elle kurulum yolundaysanız
(`README` → *Yol A* veya `KURULUM.md`) sizin yapmanız gerekir:

```bash
# 1) domain XML'ini libvirt'in dizinine kopyala
sudo mkdir -p /var/lib/libvirt/images /var/lib/libvirt/qemu
sudo cp /etc/nixos/vm-xml/win10.xml /var/lib/libvirt/

# 2) sanal diski oluştur — XML bu yolu bekliyor. Oluşturulmazsa `define`
#    başarılı olur ama `start` "failed to find drive" ile düşer.
sudo qemu-img create -f qcow2 /var/lib/libvirt/images/win10new.qcow2 120G

# 3) tanımla
sudo virsh define /var/lib/libvirt/win10.xml    # ilk kez
```

> Sıfırdan kurulumda XML `/mnt/etc/nixos/vm-xml/win10.xml` altındadır; tam
> adımlar [`KURULUM.md` §9b](KURULUM.md). Ayrıca `install.sh`'ı çalıştırmadıysanız
> XML'deki `<hostdev>` PCI adresleri depodaki varsayılandır — `lspci` ile
> eşleştirin (`nixos/hooks/qemu` içindeki `GPU_PCI` / `GPU_AUDIO` ile aynı olmalı).

```bash
sudo virsh start win10
```

> ⚠️ **VM'i masaüstü oturumunuzdan başlatmayın.** Hook, GPU'yu bırakmak için
> `loginctl terminate-user` çağırır; yani `virsh start` komutunu verdiğiniz
> oturumun kendisi kapanır. İki güvenli yol:
>
> ```bash
> # 1) ayrı TTY'den (Ctrl+Alt+F3)
> virsh start win10
>
> # 2) oturumdan bağımsız transient unit
> systemd-run --scope --unit=vmstart virsh start win10
> ```

VM çalışırken host'ta grafik oturum **yoktur** — yalnızca metin konsolu
(vt1/vt2) kullanılabilir. Bu, tek kartlı geçişin doğal sonucudur.

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
| `vm.swappiness = 180` | RAM baskınken agresif temizlemeye izin verir. (Öncelik seçmez, **yazma eğilimini** ayarlar.) |
| `hypridle` 900 sn → `systemctl suspend` | Suspend öncesi hyprlock **çağrılmaz**: foreground'da bloklar ve arkadaki suspend'e hiç sıra gelmez. Kilit zaten `before_sleep_cmd` ile yapılıyor. |
| `home.sessionVariables.HYPRLAND_CONFIG` | Hyprland 0.56 `hyprland.lua` varsa `.conf`'u sessizce tamamen yok sayar. Yol sabitlenince bu mekanizma yapısal olarak devre dışı kalır. |
| `amd_pstate=active`, `pcie_aspm=off` | Masaüstü boşluğunda güç tasarrufu. |

**Ayarların sahibi:** üç yazıcı birbiriyle yarışıyor —
`power-profiles-daemon` (CPU governor), `ananicy-cpp` (nice/ioprio) ve
`gamemode` (`renice -10`). ppd yalnız governor'a dokunmalı, ananicy scheduler
otoritesi olmalı. Oyun sırasında gamemode ikisini de ezmekte; bu bilinçli.
Oyun dışında ppd profilini `balanced`'a çekmeniz önerilir.

---

## Bilinen sınırlar

- **Navi 2x GPU reset.** RX 6000 serisi `gnif/vendor-reset`in desteklediği
  "reset bug" listesinde **yok**. VM ikinci kez açılamadığında kart PCIe
  bus'tan düşebilir. Hook bunu öngörüyor: sessiz unbind/rebind yetmezse
  `remove` + `rtcwake` ile kısa uyku + `rescan` deniyor; yine olmazsa
  konsola açık bir mesaj bırakılıp **host reboot** önerilir. Garanti değil.
- **Host'ta GPU yokken grafik yok.** VM çalışırken yalnızca metin konsolu var.
  Acil kurtarma için `Ctrl+Alt+F2` → `systemctl reboot`.
- **`HOST_USER` sabit.** Hook `localhost`'u sonlandırır. Tek kullanıcılı
  kurulum içindir; `KURULUM.md` §9b'de bu konu ayrıntılı.
- **VM'e giriş cihazı tanımlı değil.** `vm-xml/win10.xml` içindeki USB hostdev
  yorum satırında; `<graphics>`/VNC/SPICE elemanı da yok. Yani GPU
  passthrough'tan sonra host'ta grafik olmaması *beklenen* davranışken, host'a
  bağlı klavye/farenin guest'e **hiç ulaşmaması** ayrı ve çözülebilir bir eksik:
  tanımlı tek giriş yolu emüle PS/2 (`virsh console` üzerinden metin). Oyun
  için düzeltme: kendi cihazınızın VID:PID'sini bulup (host'ta
  `lsusb` → `idVendor`/`idProduct`) `win10.xml`'deki yorumlu `<hostdev
  mode="subsystem" type="usb">` bloğunu açın, ardından `virsh define` +
  `virsh start` gerekir. Hostdev `managed="yes"` olduğu için host'un cihazı
  VM'e devredilir ve VM kapanınca geri döner.
  > 💡 `2a7a:8a47` yorumdaki değer **bakımcının kendi CASUE klavyesidir** —
  > sizin cihazınız değil, kopyalamayın.
- **swap şifrelenmemiş.** LUKS dışındaki açık bölümde.
- **CSR (Client-Side Rendering).** Bu bir oyun/gaming config'i; KDE/Wayland
  gibi ağır masaüstü bileşenleri yok.
- **`wuwa-auto.sh` ekran koordinatları.** Varsayılanları 2560×1440'e göre
  yazıldı; başka çözünürlükte ekrana sığmıyorsa döngüye girmeden uyarı
  basar. `WUWA_GEOMETRY_MAIN` / `WUWA_GEOMETRY_CHOICE` ile geçersiz kılınabilir.
  Boşta kaldığında 3 sn → 30 sn arası kademeli bekler, yani gün boyu sürekli
  OCR yapmaz.
- **`assets/` klasörü config'e bağlı değil.** Ekran görüntüleridir.
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
├── assets/                       ← ekran görüntüleri (config'e bağlı değil)
├── docs/archive/                 ← eski analiz raporları (arşiv — doğrulama için değil)
├── scripts/
│   └── extract-embedded-scripts.py   ← home.nix'e gömülü bash'i diske çıkarır (CI için)
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
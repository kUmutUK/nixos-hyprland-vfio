> # ⛔ SÜPERSEDED — GÜNCEL KOD İÇİN KULLANMA
>
> Bu rapor `nixos-hyprland-vfio(1)(2)(3)(4).zip` birleşimi için yazıldı.
> Aşağıdaki hüküm **artık doğru DEĞİLDİR.** Özellikle §0'ın
> *"sistem şu an hâliyle derlenmiyor"* hükmü ve `installPhase` ile
> `python3` maddeleri düzeltilmiştir:
>
> - `low-latency_layer` özel `installPhase`'i kaldırıldı
> - `python3` `environment.systemPackages`'a eklendi
>
> Güncel düzeltme kaydı tek yerde: `CHANGELOG.md` → `[1.3.0]`.
> Arşivdeki diğer raporlar ve bu klasörün amacı: `docs/archive/README.md`.
>
> ⚠️ Aşağıdaki metin, neyi doğruladığınıza dair iyi niyetli bir kayıttır
> ve tarihsel değerini korur — ama bir sonraki adımını buradan planlamayın.

# `nixos-hyprland-vfio(1)(2)(3)(4).zip` — Kapsamlı Kod & Yapılandırma Analizi

**Tarih:** 2026-10-05 · **Yöntem:** statik okuma + CI kapılarının yerelde yeniden koşumu + gerçek `nix flake check` + gerçek `nix build` (derleme) + upstream kaynak doğrulaması
**Kapsam:** 22 dosya / ~7 MB · kod ~2.130 satır, dokümantasyon ~2.890 satır

---

## 0. Kısa hüküm

Bu repo **olağanüstü dürüst ve iyi düşünülmüş** bir NixOS config. CHANGELOG'daki düzeltmelerin büyük çoğunluğu gerçek, kaynak destekli ve doğru; CI'ın "kapı gücü" iddiası da boş bir iddia değil — bizzat test ettim ve çalışıyor.

**Ama sistem şu an hâliyle derlenmiyor.** `low-latency-layer` türetmesindeki gereksiz `installPhase` bloğu, ilk `nixos-rebuild`'i kesin olarak düşürüyor. Bunu tahmin etmiyorum — paketi gerçekten derlettim ve hata çıktı, sonra düzeltmeyi uygulayıp yeniden derlettim ve başarılı oldu.

İkinci önemli bulgu: `install.sh`'ın `python3`'ye bağlı olan VM XML senkronizasyonu, kurulu sistemde `python3` olmadığı için **her zaman "python3 yok" uyarısına düşüyor**, yani bu özelliği hiç çalıştırmıyor.

---

## 1. Gerçekten ne doğruladım

Bazıları zordu, o yüzden "okudum" ile "çalıştırdım"ı ayırıyorum:

| # | Doğrulama | Yöntem | Sonuç |
|---|---|---|---|
| 1 | CI kapı 1: `shellcheck -S warning install.sh nixos/hooks/qemu` | shellcheck 0.9.0 kurulup koşuldu | ✅ exit 0 |
| 2 | CI kapı 2: `home.nix`'teki gömülü script'ler | `extract-embedded-scripts.py` çalıştırıldı → 7 script çıktı, hepsi `bash -n` + shellcheck'ten geçti | ✅ |
| 3 | CI kapı 3: `nix flake check --no-build` | Nix 2.35.2 kurulup koşuldu | ✅ **"all checks passed!"** |
| 4 | `flake.lock` kanonik mi? | Eval sonrası `git diff -- flake.lock` | ✅ boş — sürüklenme yok |
| 5 | Kapı gerçekten option hatası yakalıyor mu? | `services.tamam-boyle-bir-option-yok` enjekte edildi | ✅ **exit 1**, hatayı verdi |
| 6 | Home Manager tarafını da yakalıyor mu? | `programs.boyle-boyle-yok-bir-modul` enjekte edildi | ✅ **exit 1** |
| 7 | `flake.lock` sürüklenme koruması işe yarıyor mu? | `impermanence.inputs.home-manager.follows` silindi → `home-manager_2` node'u belirdi, lock yeniden yazıldı | ✅ guard kırar |
| 8 | `low_latency_layer` sha256 doğru mu? | `nix-prefetch-url --unpack` ile gerçek NAR hash'i hesaplandı | ✅ **tıpatıp aynı** |
| 9 | `low_latency_layer` derleniyor mu? | Gerçek `nix build` | ❌ **PATLADI** (aşağıda P0-1) |
| 10 | Düzeltme çalışıyor mu? | `installPhase` kaldırılarak yeniden `nix build` | ✅ başarılı, manifest tam yolda |
| 11 | `services.lsfg-vk` option'ı gerçekten var mı? | `pabloaul/lsfg-vk-flake@62aadfc` → `module.nix` okundu | ✅ `enable` + `ui.enable` birebir |
| 12 | `/run/libvirt/nix-ovmf`, `/run/libvirt/nix-emulators`, `hooks.qemu.<n>` | nixpkgs `7a0f122` `libvirtd.nix` okundu | ✅ üçü de doğru, `win10.xml`'in yolları geçerli |
| 13 | `/etc/vulkan`'a kaç katman yazılıyor? | `nix eval` ile `environment.etc` listelendi | 2 (aşağıda P2-6) |
| 14 | `qemu-img` / `python3` / `mpv` PATH'te mi? | `nix eval` ile `environment.systemPackages` (264 paket) tarandı | qemu ✔ / python3 ✘ / mpv ✘ |

---

## 2. 🔴 P0-1 — Tüm sistem build'ini düşüren hata (doğrulandı, düzeltildi)

**Dosya:** `nixos/configuration.nix:37-41`

```nix
installPhase = ''
  runHook preInstall
  cmake --install build
  runHook postInstall
'';
```

**Sorun:** NixOS'un cmake setup hook'u `buildPhase` içinde zaten `cmake --build build --target install` çalıştırır ve **build bittiğinde cwd `<source>/build`'dir**. Özel `installPhase` bu dizinden `cmake --install build` dediği için `<source>/build/build/` arar:

```
[100%] Built target VkLayer_KORTHOS_LowLatency
buildPhase completed in 3 minutes 27 seconds
Running phase: installPhase
CMake Error: Not a file: .../source/build/build/cmake_install.cmake
```

**Etki:** `low-latency-layer` `environment.systemPackages` içinde olduğu için bu tek hata **tek başına `nixos-rebuild switch`'i düşürür.** Kullanıcı config'i ilk kez kurduğunda, `nix flake check` geçtiği için sorunu görmez ve `switch` aşamasında duvara çarpar. CHANGELOG bunu "hâlâ açık" diye işaretlemişti — şimdi kesin olarak cevaplandı.

**Düzeltme:** Özel `installPhase`'i tamamen silmek.

```
installPhase'li hâli  : %100 derlendi → installPhase'de PATLADI   ✘
installPhase'siz hâli: başarılı → doğru çıktı                   ✔
```

Hazırladığım yamayı `0001-low-latency-layer-build-duzeltmesi.patch` olarak ekledim; uygulanmış `configuration.nix` hâlâ `all checks passed!` veriyor.

### Bu sırada doğrulanan (doğru olan) kısımlar

Yama uygulanmış halde üretilen çıktı:

```
/nix/store/dpb2n1z417ddw4isfh4yazg7j74kw7nc-low_latency_layer-1.0.0/
├── lib/libVkLayer_KORTHOS_LowLatency.so
└── share/vulkan/implicit_layer.d/low_latency_layer.json   ← configuration.nix'in beklediği yol, birebir
```

Manifest içeriği, `docs/archive/DEGISIKLIKLER.md`'nin iddialarını doğruluyor:

```json
{
  "layer": {
    "name": "VK_LAYER_KORTHOS_low_latency",
    "type": "GLOBAL",
    "library_path": "/nix/store/...-low_latency_layer-1.0.0/lib/libVkLayer_KORTHOS_LowLatency.so",
    "api_version": "1.3.0",
    "functions": { "vkGetInstanceProcAddr": "...", "vkGetDeviceProcAddr": "..." },
    "disable_environment": { "DISABLE_LOW_LATENCY_LAYER": "1" }
  }
}
```

- `library_path` **mutlak store yolu** → `symlinkJoin`/`runtimePath` gerekmiyor, DEGISIKLIKLER.md haklı. `ldd` ile doğruladım: `.so`, `libvulkan.so.1`'i kendi RPATH'iyle çözüyor.
- **`enable_environment` yok** → katman varsayılan etkin, `DISABLE_LOW_LATENCY_LAYER` ile kapatılıyor. `configuration.nix`'in `LOW_LATENCY_LAYER_REFLEX = "1"` yorumu doğru.
- `vulkan-loader`'ı `buildInputs`'a koymak doğruymuş: configure logu `Found Vulkan: .../libvulkan.so (found version "1.4.357")` diyor, yani `find_package(Vulkan)` ondan geliyor. Bu satır silinseydi derleme daha da erken kırılırdı.
- `sha256` **doğru**. (CHANGELOG bunu "hiç test edilmemiş" diye açık risk sayıyordu.)

---

## 3. 🟠 P1 — Diğer gerçek hatalar

### P1-1 · `install.sh` VM XML senkronizasyonu hiç çalışmıyor

`install.sh:223` → `command -v python3` kontrolü var, python3 yoksa "XML'i elle düzenle" uyarısı düşüyor ve **devam ediyor**. Kurulu sistemde 264 paketi taradım: **`python3` yok** (nixpkgs `system-path.nix`'teki `corePackages` listesinde de yok — orada sadece `perl rsync strace` ve `util-linux`, `mkpasswd`, `procps`, `su` gibi çekirdek şeyler var).

**Sonuç:** `vm-xml/win10.xml` içindeki `<address domain="0x0000" bus="0x0b" .../>` bloğu **dokunulmadan kalıyor**. Kullanıcı GPU'sunu farklı bir slot'a taşıdıysa, hook yeni adrese `vfio-pci` bind ediyor ama libvirt hâlâ `0b:00.0` arıyor → `virsh start` "device not found" ile başlamıyor. CHANGELOG 1.3.0 bu senaryoyu düzelttiğini yazıyordu; düzeltme kodda var ama **tetiklenmiyor**.

**Öneri:** `install.sh`'a `sudo nix shell nixpkgs#python3 -c python3 ...` ya da python3'ü `environment.systemPackages`'a eklemek (en temizi ikincisi).

### P1-2 · `pypr` müzik scratchpad'ı çalışmıyor (`mpv` kurulu değil)

`home.nix:909` → `command = "mpv --class pypr-music --no-config --idle"`, hemen üstündeki yorum da *"mpv, zaten kurulu"* diyor.

**Gerçek:** `mpv` ne `environment.systemPackages`'ta ne `home.packages`'ta var. `mpvpaper` var ama o kendi `Environment = "PATH=${lib.makeBinPath [ pkgs.mpvpaper pkgs.mpv ]}"` ile mpv'yi **kendi unit'ine özel** ekliyor — yani duvar kağıdı çalışır, scratchpad çalışmaz.

`SUPER+SHIFT+S` → pypr "mpv yok" diye pencer açmayacak, toggle sessizce boşa düşecek.

**Düzeltme:** `home.packages`'a `mpv` eklemek.

### P1-3 · `polkit.service` durduruluyor, geri açılmıyor

`hooks/qemu:126` — `stop_hyprland()` içinde durdurulan servisler:

```bash
for svc in ollama polkit.service; do
  systemctl stop "$svc"
done
```

`hooks/qemu:188` — `start_hyprland()` ise yalnızca `ollama`'yı geri açıyor. **`polkit.service` kalıcı olarak kapalı kalıyor.**

Bu, VM kapandıktan sonra sistemin polkit yetki otoritesini kaybettiği anlamına geliyor: disk bağlama, ağ değişikliği, "Güç Yönetimi" gibi işlemlerde yetki penceresi çıkmaz. Kullanıcı bunu "polkit bozuk" diye yaşar,VFIO ile ilişkilendiremez. Hook'un `polkit`'i durdurma gerekçesi GPU'yu serbest bırakmaktı (GPU'yu tutan kullanıcı servislerini kapatma), ama `polkit.service` GPU tutmaz ve zaten **sistem** servisidir — `stop_hyprland` içindeki yorum ("GPU kullanan servisler") bu iki servisi birbirine karıştırıyor.

**Düzeltme:** `start_hyprland()` içine `polkit.service` için de aynı `is-enabled`/`start` bloğunu eklemek (3 satır).

### P1-4 · `rtcwake -m mem` kurtarması host'u kalıcı uyutabilir

`hooks/qemu:62-67` — `suspend_rescan_recovery()` cihazı PCI ağacından kaldırıp `rtcwake -m mem -s 3` çağırıyor. Bu, **libvirt `release` hook'u çalışırken, otomatik olarak, host'u askıya alıyor.**

RTC alarmı BIOS'ta kapalıysa ya da "Resume by RTC" desteklenmiyorsa host bir daha kendiliğinden uyanmaz. Kullanıcı fiziksel olarak güç düğmesine basmak zorunda kalır. Üstelik bu, GPU'nun geri gelmediği en kötü senaryoda tetikleniyor — yani sistem zaten sinirliyken.

`log` satırı askıya almadan *önce* yazıldığı için niyet `/var/log/libvirt/vfio.log`'da duruyor (iyi), ama bu bir "beklenmedik karşılaşılan askı" değil, otomatik bir askı. README'de bu davranışın riski hiç anlatılmıyor.

**Öneri:** En azından `rtcwake` öncesi ekrana/tty'ye uyarı basmak ve bu fallback'i bir option ile kapatılabilir yapmak (`services.vfio.allowSuspendRecovery = lib.mkDefault true`).

### P1-5 · `vendor_reset`, `vfio-pci`'ye bind **sonrasında** çağrılıyor

`hooks/qemu:241-242`:

```bash
bind_vfio "$GPU_PCI" "$GPU_AUDIO"
vendor_reset "$GPU_PCI"
```

FLR (`echo 1 > .../reset`), cihaz zaten `vfio-pci`'ye bağlandıktan sonra yapılıyor. İki sorun var:

1. `vfio-pci` bind sırasında zaten bir reset gerçekleştiriyor; bind sonrası yapılan ikinci reset gereksiz.
2. Navi2x reset bug'ının en çok konuşulan tetikleyicisi tam olarak bu sıradaki gereksiz resetlerden biri. Hook'un kendi yorumu bu kartlarda reset'in sorunlu olduğunu kabul ediyor, ama reset'i en riskli ana koymuş.

**Öneri:** `vendor_reset`'i `bind_vfio`'dan **önce** çağırmak veya hiç kaldırmak (bind zaten yapıyor).

---

## 4. 🟡 P2 — Orta seviye

### P2-1 · `hyprlandMonitorLine` boş monitör adı → çok monitörde bozuk
`home.nix:7` → `monitor = ,preferred,auto,1`. Alanları sayarsak: 13. alan `preferred`, 14. `mirror`, 15. `workspace`. Yani bu satır pratikte **"tüm monitörleri workspace 1'e aynala"** demek. Tek monitörde zararsız (zaten varsayılan), çok monitörde kurulumu sessizce bozar. CHANGELOG bunu açık sayıyor; `install.sh`'in doldurduğu için yeni kurulumda sorun olmuyor, ama **repo'yu doğrudan klonlayıp `nixos-rebuild` çalıştıran** biri bu hâliyle kalır.

### P2-2 · `nixfmt-rfc-style` artık deprecated
Gerçek eval sırasında şu uyarıyı aldım:
```
evaluation warning: nixfmt-rfc-style is now the same as pkgs.nixfmt which should be used instead.
```
`flake.nix:98` ve `CONTRIBUTING.md:44` hâlâ `nixfmt-rfc-style` diyor. Repoda bu uyarıya karşılık **hiçbir not yok** (diğer bütün eval uyarıları çok dikkatli belgelenmiş).

### P2-3 · "3 Vulkan katmanı aktif" iddiası yanlış — 2
`CHANGELOG.md:1.3.0` "aynı anda 3 Vulkan implicit layer aktif (`lsfg-vk` + `low_latency_layer` + `vkbasalt`)" diyor. Gerçekte `environment.etc` altında sadece **iki** manifest var:
```
vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json
vulkan/implicit_layer.d/low_latency_layer.json
```
`vkbasalt` `environment.systemPackages`'ta var ama nixpkgs onun manifest'ini `$out/share/vulkan/implicit_layer.d/` altına koyar, `/etc/vulkan`'a bağlayan hiçbir şey yok; `VK_INSTANCE_LAYERS` / `VK_LOADER_LAYERS` / `VK_LAYER_PATH` da hiçbir yerde ayarlanmıyor. **Yani `vkbasalt` hiç yüklenmiyor** — ölü bir sistemPackages girdisi.

### P2-4 · `fuser`'ın "GPU serbest" yargısı güvenilmez
`hooks/qemu:160` → `if ! fuser $nodes; then break; fi`. `fuser` hem "kimse kullanmıyor" hem de "böyle bir dosya yok" durumunda exit 1 verir, `2>/dev/null` ile ayrımı da yok oluyor. `/dev/dri/card0` yoksa (ya da `gpu_drm_card` yanlış cihazı bulursa) hook "GPU serbest" deyip VFIO bind'e devam ediyor. `docs/archive/DEGISIKLIKLER.md` bunu "bilerek dokunulmadı" diye işaretliyor; ben de aynı sonuca varıyorum ama etkisi sandığından büyük: sessizce yarım bağlı sistem demek.

### P2-5 · `install.sh` `sudo`/`qemu-img` için transitif bağımlılığa güveniyor
`qemu-img` (satır 324) ve `sudo` (her yerde) sistemde **var** — ama ikisi de config'in *açıkça* tanımladığı bir şeyden gelmiyor, modül zincirinin yan ürünü. `virtualisation.libvirtd` `environment.systemPackages`'a `qemu`'yu koyuyor (bu doğru ve kastedilmiş), `sudo` ise başka bir nixpkgs modülü aracılığıyla geliyor. Bir modül bunları düşürdüğü anda `install.sh` sessizce hatalı yere düşer. `qemu-img` satırında `set -e` yüzünden hata olursa script orada **duruyor** — yani `/nix/persist/home`, değişken dönüşümleri ve son checklist'e hiç ulaşılamıyor.

Ayrıca `install.sh:348` `apply_var`'ın `sed -E` kalıbında kullanıcı girdisi doğrudan giriyor; `&` veya `\` içeren bir monitör satırı ifadeyi bozuyor. Doğrulaması da zayıf (`grep -qF "\"değer\";"`).

### P2-6 · `security.pam.loginLimits`'taki `@gamemode` kuralı ölü
`configuration.nix:164` → `{ domain = "@gamemode"; item = "nice"; type = "-"; value = "-10"; }`. gamemode modülü bir PAM grubu oluşturmuyor ve `renice`'i daemon üzerinden yapıyor. Kural zararsız ama hiçbir şey yapmıyor; `programs.gamemode` zaten aynı işi yapıyor.

### P2-7 · Dokümantasyondaki commit hash'leri gerçekle uyuşmuyor
Zip içindeki tek commit `0137b38` ("Add files via upload"). Ama dokümanlar `0d35833` (CHANGELOG 1.3.0 + `docs/archive/README.md`), `602f217` (`DEGISIKLIKLER.md`), `97a1665` (arşivlenen rapor) diyor. Üç ayrı hash, hiçbiri mevcut değil. Bir repo'nun temel satış argümanı "her iddia upstream'e karşı doğrulandı" ise, kendi provenance kaydı tutarsız olmamalı.

### P2-8 · `home.persistence` + `xdg.configFile` çakışması (risk)
`home.nix:1241` `home.persistence."/nix/persist/home".files = [ ".config/lsfg-vk/conf.toml" ]` ile `xdg.configFile."lsfg-vk/conf.toml"` aynı dosyayı iki farklı mekanizmayla yazıyor. İlk aktivasyonda impermanence bind-mount'u `xdg.configFile`'ın symlink'ini gölgeleyebilir. `configuration.nix`'teki yorum `/etc` için bu tuzağı fark edip kaçınmış ama `home` tarafındaki karşılığına dokunmamış. Çalışma ihtimali yüksek, ama `/etc` tarafındakiyle aynı sınıf risk — gözlemlenmeli.

---

## 5. 🔵 P3 — Küçük / hijyen

- **Paket tekrarları:** `hyprpicker`, `playerctl`, `wev` hem `environment.systemPackages`'ta hem `home.packages`'ta; `pyprland` hem `configuration.nix` hem `flake.nix`'te. Zararsız ama PATH'i kirletiyor.
- **CI'da `statix`/`deadnix` gate değil**, ayrıca `nix run nixpkgs#statix` **kilitlenmemiş** nixpkgs çekiyor — aynı commit'te farklı sonuç verebilir. `flake.nix` devShell'te ikisi de var; CI `nix develop` kullanmıyor.
- **CI yorum bloğu tekrarlanıyor:** `check.yml:38-43` ve `44-50` aynı paragrafı iki kez içeriyor (biri step'in üstünde, biri içinde).
- **CONTRIBUTING ile CI uyumsuzluğu:** CONTRIBUTING `shellcheck install.sh nixos/hooks/qemu` diyor (`shellcheck`'in varsayılanı `style` seviyesi), CI ise `-S warning` kullanıyor. Yerelde geçen bir şey CI'da farklı görünebilir.
- **Extractor'da gizli tuzak:** `scripts/extract-embedded-scripts.py:112,120` `lines.index(line)` kullanıyor — bu, **dosyada ilk eşleşen** satırı döndürür. Şu an 7 marker satırının hiçbiri tekrar etmiyor (kontrol ettim), dolayısıyla **latent** bir hata; ileride iki aynı isimli script eklenirse sessizce yanlış bloğu çıkarır. `enumerate` + indeks kullanılmalı.
- **`extract-embedded-scripts.py` çıktısı çalıştırılabilir değil** (`"libnotifynotify-send"`, `"dbusdbus-monitor"` gibi birleşik yollar). Shellcheck içinsinçidir, ama docstring "shellcheck'e zincirlenebilir" derken yanıltmıyor.
- **Repo şişkinliği:** `assets/wall-.png` tek başına 3.0 MB (repoya ekran görüntüsü koymak için çok büyük; Git LFS veya küçültme), `docs/archive/` 73 KB ve README'de hâlâ "repodaki en güncel belgelendirme" muamelesi görüyor (kendileri de "arşiv, kullanma" diyor — ya silmeli ya de `docs/` dışına taşımalılar).
- **`home.nix` sonunda girinti bozuluyor:** `services.hypridle` bloğu 1482'de `};` ile kapanıyor, sonra `systemd.user.services = {` aynı seviyede başlıyor. Nix sözdiziminde geçerli (doğruladım, eval ediyor) ama okunabilirlik kötü ve `nixfmt` bunu düzeltmez.

---

## 6. Gerçekten iyi yapılmış kısımlar

Bunları söylemek de gerek, çünkü az değil:

1. **Dokümantasyon yorumları olağanüstü.** Her "DÜZELTME (tarih)" notu neyi, nedenini, hangi satırı etkilediğini ve alternatiflerini açıklıyor. `configuration.nix:137-148`'deki `vm.swappiness`/`priority` açıklaması — "hangi swap kullanılacak" ile "ne kadar agresif swap'e gidilecek" mekanizmalarını karıştırmadan ayıran özet, kusursuz.

2. **libvirt hook yolu tespiti doğru.** `configuration.nix:51-54` + `flake.nix`'in `hooks.qemu.vfio` kullanımı. nixpkgs `libvirtd.nix`'i okuyarak doğruladım: `/var/lib/libvirt/hooks/qemu.d/<isim>` symlink'i, `/etc/libvirt/hooks` **hiç** okunmuyor. Bu, "VFIO hiç çalışmıyor" seviyesinde bir hata ve doğru düzeltilmiş.

3. **Shebang/PATH injection sorunu doğru çözülmüş.** `configuration.nix:79` `ls` için `findutils`, `sed` için `gnused` enjekte ediyor — ikisi de `coreutils` DEĞİL, yorum bunu açıkça söylüyor. Hook'un PATH'i tam olarak ihtiyaç duyduğu 5 araçla sınırlı.

4. **Rollback mantığı gerçek.** `stop_hyprland` artık gerçek timeout dönüyor, `device_bound_to_vfio` kontrolü ile bind başarısızlığı yakalanıp `exit 1` ile libvirt'e bildiriliyor. Eskiden masaüstü kapalı kalıp GPU da gitmiş sessiz bir yarım durum bırakıyordu.

5. **Ayrışma sırası düzeltmesi doğru.** `release_host_driver()` artık `.0`'ı `amdgpu`'ya zorlamıyor, `driver_override`'ı temizleyip `drivers_probe`'a bırakıyor — böylece ses fonksiyonu `.1` doğru sürücüyü (`snd_hda_intel`) kendisi buluyor. Bu, `XF86`/HDMI sesinin VM'de çalışması için şart.

6. **SSH güvenliği.** Bakımcının açık anahtarı `authorizedKeys` listesinden **kaldırılmış** (eski sürümde bu, config'i kuran herkese uzaktan giriş veriyordu) ve liste boş bırakılmış. `PasswordAuthentication = false` + boş liste = uzaktan giriş yok; bu pahası bir seçim ama **farkında ve belgelenmiş**, üstelik "reboot etmeden önce SSH yolunu aç" diye uyarıyor.

7. **CI gerçekten işe yarıyor.** Testlerime göre kapı, NixOS option hatalarını, Home Manager option hatalarını ve lock sürüklenmesini yakalıyor. `statix`/`deadnix`'i gate yapmamış olması eksik ama `shellcheck`'i gate'e alması ve embedded script'leri tarayacak `extract-embedded-scripts.py`'yi yazması — yani "gömülü script'ler taranmıyordu" boşluğunu kapatması — az bulunan bir emek.

8. **`install.sh`'ın XML patch'i kaynak dosyayı kirletmiyor.** Eski `git update-index --skip-worktree` desenini kaldırmışlar, patch'lenmiş XML doğrudan `/var/lib/libvirt/win10.xml`'e yazılıyor. 3+ hostdev durumunda da artık sessizce `sys.exit(1)` yerine uyarı basıyor.

9. **davinci-resolve gerekçeleri tutarlı.** Impermanence uyarısının neden "çözülmediği" (`method` option'ı kaldırılmış, `environment.persistence` eklemek daha ağır hata veriyor) gerçek bir ölçümden geliyor ve benim eval'imde aynı uyarıyı gördüm.

---

## 7. Dosya dosya özet

| Dosya | Satır | Kod | Yorum | Değerlendirme |
|---|---:|---:|---:|---|
| `nixos/home.nix` | 1542 | 1141 | 272 | Tek doğruluk kaynağı olması doğru karar. P1-2 (`mpv`), P2-1 (boş monitör), P2-8 (persistence çakışması) burada. |
| `nixos/configuration.nix` | 667 | 396 | 217 | **P0-1 burada.** Yorum yoğunluğu yarar sağlıyor. P2-6 ölü PAM kuralı. |
| `install.sh` | 429 | 343 | 39 | P1-1 ve P2-5. Mantık akışı iyi, varsayımları fazla. |
| `nixos/hooks/qemu` | 299 | 187 | 91 | En kritik dosya. P1-3, P1-4, P1-5, P2-4. |
| `scripts/extract-embedded-scripts.py` | 132 | 95 | 13 | CI için gerçekten gerekli. P3'teki `lines.index` tuzağı. |
| `vm-xml/win10.xml` | 213 | 213 | 0 | OVMF/emulator yolları NixOS için geçerli (doğrulandı). `migratable="on"` + `host-passthrough` CPU biraz çelişkili, zararsız. |
| `nixos/hardware-configuration.nix` | 86 | 60 | 14 | `@home/.snapshots` alt hacim mantığı doğru. |
| `nixos/flake.nix` | 115 | 68 | 40 | P2-2 (deprecated formatter). |
| `.github/workflows/check.yml` | 117 | 47 | 60 | Gerçekten işe yarıyor (test edildi). P3'teki tekrarlar. |
| `CHANGELOG.md` | 659 | — | — | Olağanüstü detaylı, P2-3 ve P2-7'de kendi içinde hatalı. |
| `README.md` / `KURULUM.md` | 475 | — | — | Tutarlı ve doğru. `README` İngilizce, `KURULUM` Türkçe. |

---

## 8. Önerilen aksiyon sırası

**Hemen (build'i kurtarır):**
1. P0-1 — `low_latency_layer` `installPhase`'ini sil. → `0001-low-latency-layer-build-duzeltmesi.patch`

**Bu hafta (gerçek kırılmalar):**
2. P1-3 — `start_hyprland()`'a `polkit.service` geri açılışını ekle (3 satır).
3. P1-2 — `home.packages`'a `mpv` ekle.
4. P1-1 — `environment.systemPackages`'a `python3` ekle veya `install.sh`'ı `nix shell nixpkgs#python3` ile sarmalayın.
5. P1-5 — `vendor_reset`'i `bind_vfio`'dan önce çağır.

**Bu ay (risk azaltma):**
6. P1-4 — `rtcwake` fallback'ini option ile kapatılabilir yap, öncesine tty uyarısı bas.
7. P2-2 — `nixfmt-rfc-style` → `pkgs.nixfmt`.
8. P2-7 — Dokümandaki commit hash'lerini gerçek `0137b38` ile hizala.
9. P2-3 — CHANGELOG'daki "3 katman" iddiasını 2'ye düzelt; `vkbasalt`'ın sistemde neden yüklenmediğini ya yaz ya da paketi kaldır.
10. P3 — `statix`/`deadnix`'i devShell üzerinden `nix develop --command` ile, kilitli nixpkgs ile çalıştır ve gate yap.

---

## 9. Doğrulayamadıklarım

Dürüstlük için: bunlar makinesiz test edilemez, sadece statik okumayla yorum yapabildim.

- **VFIO hook'unun gerçekten GPU'yu bind ettiği.** Hook mantığını satır satır izledim, mantık doğru görünüyor; ama Navi2x reset bug'ı donanıma özgü ve burada ölçemem.
- **`rtcwake -m mem`'in gerçekten S3'e düşüp düşmediği** — BIOS'a bağlı.
- **hyprland.lua önceliği.** `docs/archive/README.md`'nin "pratikte gerçekleşmiyor" argümanı (`findConfig` yalnızca `XDG_CONFIG_*` altına bakıyor, NixOS'un stub'ı `/run/current-system/sw/share/hypr` altında) inandırıcı ve tutarlı; ama 0.56.2'nin kaynak kodunu kendim okumadım.
- **Waybar/GTK CSS çıktısının görsel doğruluğu.**
- **`home.persistence` + `xdg.configFile` ilk aktivasyon davranışı** (P2-8) — gerçek bir rebuild gerektirir.
- **`impermanence` uyarısının "pratik etkisi düşük" iddiası** — UID'lerin `allocId` ile kararlı kaldığına dair makine üstünde gözlem yapamadım.

---

*Analiz `/workspace/work/nixos-hyprland-vfio` üzerinde yapıldı. `configuration.nix` P0-1 düzeltmesiyle yamalandı ve yamadan sonra da `nix flake check --no-build` → "all checks passed!" doğrulandı.*
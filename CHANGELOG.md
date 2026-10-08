# 📜 Changelog

All notable changes to this project will be documented here.

This project follows:
- Keep a Changelog
- Semantic Versioning

---

# [1.3.4] - 2026-10-08

Bağımsız inceleme turu. Bulgular tekrar gözden geçirildi; iki tanesi
**çekildi**, iki tanesi **düzeltildi**, bir tanesi **sınırlama olarak
yeniden sınıflandırıldı**. Aşağıda neyin neden değiştiği açık.

## 🔴 Fixed — CI kapısı, hiçbir şey taramadan yeşil kalıyordu

- **`.github/workflows/check.yml`, "Embedded home.nix scripts" adımı:**
  ```bash
  python3 scripts/extract-embedded-scripts.py /tmp/emb | xargs -0 -n1 -- shellcheck -S warning
  ```
  İki ayrı zaafiyet üst üste biniyordu:
  1. `xargs`'ta **`-r` / `--no-run-if-empty` yoktu**. Boş girdide xargs
     komutu **sıfır argümanla bir kez** çalıştırır; shellcheck dosya adı
     almayınca stdin'i okur, pipe boşaldığı için temiz çıkar, `exit 0` döner.
  2. Bu step'te **`shell:` anahtarı tanımlı değil**, yani GitHub Actions'ın
     varsayılanı `bash -e {0}` — **`pipefail` YOK**. (`shell: bash` yazılsaydı
     `bash -eo pipefail` olurdu.) Dolayısıyla extractor'ın **çökmesi** de
     aynı şekilde yutuluyordu; `set -e` sol tarafı korumuyor.

  Sonuç: `home.nix` içindeki `hypr/scripts/...` desenleri bir refactor'da
  kayarsa extractor **0 betik** bulup mutlu mesut çıkıyor, `echo "OK"`
  basıyor, kapı yeşil kalıyor ve hiçbir şey taranmamış oluyordu. Bu tam
  olarak `[1.3.0]`'ta bu adımı ekleme gerekçesi olarak yazılan hata sınıfı.

- → `shell: bash` eklendi (pipefail açık), **boş çıktı açıkça reddediliyor**,
  betik sayısı 7'nin altına düşerse uyarı veriyor, `xargs` artık `-r` alıyor
  ve sonuçta kaç betiğin tarandığı yazdırılıyor. Doğrulama: extractor
  sandbox'ta normal çalışmada 7 betik üretiyor; 0 betik senaryosu artık
  `::error::` ile kırılıyor.

## 🟠 Fixed — `hyprlandMonitorLine` yorumu kendi değerini yanlış tanımlıyordu

- `home.nix`'teki P2-1 yorumu *"buradaki değer yalnızca manuel klonlayanları
  **korur**"* diyordu — ama duran değer `monitor = ,preferred,auto,1`, yani
  **boş monitör adıydı: sorunun kendisi.** Yorum doğru teşhisi yapıp yanlış
  sonuca bağlanıyordu; elle klonlayan tam olarak o bozuk davranışı alıyordu.
- → Değer `KURULUM.md` §7b'in de zaten önerdiği gerçek bir örneğe çevrildi
  (`monitor = DP-1,preferred,auto,1`) ve yorum yeniden yazıldı. `KURULUM.md` §7b
  tablosundaki varsayılan sütunu da buna göre güncellendi.

## 🟡 Fixed — `docs/archive/` iki raporun varlığı belirsizdi

- `docs/archive/README.md` yalnızca iki `-SUPERSEDED` dosyayı açıklıyordu;
  `NIXOS-HYPRLAND-VFIO-ANALIZ.md` ve `DEGISIKLIKLER.md` hiç anılmıyordu.
  Klasör seviyesindeki genel afiş ikisini de kapsıyordu, **ama bir kullanıcı
  doğrudan dosyayı açtığında** karşılayacağı ilk şey kendi güçlü hükmüydü
  (*"sistem şu an hâliyle derlenmiyor"*).
- ⚠️ `NIXOS-HYPRLAND-VFIO-ANALIZ.md`'in **iki hükmü artık geçersiz** ve
  düzeltilmiş: `low_latency_layer`'ın özel `installPhase`'i kaldırıldı,
  `python3` `environment.systemPackages`'a eklendi.
- → Dört raporun tamamı `docs/archive/README.md`'de tek tek listelendi, her
  biri için "güncel kodda hangi maddesi geçersiz" tablosu eklendi, ve
  `NIXOS-HYPRLAND-VFIO-ANALIZ.md`'in en üstüne ⛔ SÜPERSEDED afişi kondu.
  Yeni arşiv dosyası eklenirse ne yapılacağı da klasör README'sine yazıldı.
- `[1.3.2]`'deki *"docs/archive/ (~92 KB, **4 dosya**)"* sayımı da düzeltildi
  (klasörde 5 dosya var, `README.md` dahil).

## 📝 Belgelenmemiş davranış açıklandı (davranış DEĞİŞTİRİLMEDİ)

- **`home.nix` → `services.hypridle`, 150 sn'lik parlaklık adımı.**
  `brightnessctl -s set 70%` bir "karartma" değil, **mutlak %70'e sabitlemedir**;
  yönü tamamen başlangıç değerine bağlıdır (%40'ta çalışıyorsa parlatır,
  %100'de çalışıyorsa kısar). Ayrıca harici monitörlü masaüstülerde
  `/sys/class/backlight/` genelde boş olduğu için bu satır büyük olasılıkla
  **sessiz bir no-op**tur.
  Zamanlama bağlamı: 150 sn'de parlaklık, 300 sn'de `dpms off` — yani
  150–300 sn arası ekran açık kalıyor.
- → Yalnızca **yorum eklendi**. Tasarımın sahibinin tercihi olduğu için
  davranış değiştirilmedi; doğru alternatifler (`--set 10%-` ya da listener'ı
  kaldırmak) yorumda belirtildi.

## ⚠️ Yeniden sınıflandırıldı — `HOST_USER` bir hata değil, sınırlama

- `hooks/qemu:145` → `loginctl terminate-user "${HOST_USER:-localhost}"`
  kullanıyor ve `HOST_USER`'ı **kimse export etmiyor** (bu doğrulandı,
  config'in hiçbir yerinde geçmiyor).
- **Ancak:** `configuration.nix` kullanıcı adını zaten `localhost`'a sabitliyor
  (`users.users.localhost`), `home.nix` de `home.username = "localhost"` diyor ve
  `install.sh` kullanıcı adı **sormuyor**. Yani varsayılan akışta fallback
  doğru kullanıcıyı sonlandırıyor, kurulum çalışıyor.
- Sorun **yalnızca** kullanıcı hesap adını config'in 3+ noktasından
  (`users.users.X`, `home-manager.users.X`, `home.username`) değiştirirse
  ortaya çıkıyor: oturumlar kapanmıyor → GPU kilitli kalıyor →
  `stop_hyprland` zaman aşımı → rollback → VM açılmıyor.
- → Kod **değiştirilmedi**. `[1.3.3]`'te doğru teşhis zaten konmuş ve doğru
  çözüm ("`virtualisation.libvirtd.hooks.qemu`'ya `environment` eklemek")
  yazılmış; bunu uygulamak, hesap adını özelleştirenler için ayrı bir karar.

## ❌ Çekilen iki iddia

Daha önce öne sürülen, tur sonunda **doğrulanamayan** iki madde:

- **"CI'da `pipefail` extractor'ın çökmesini yakalar"** — bu workflow için
  **yanlış**. `shell:` anahtarı olmadığı için GitHub Actions `bash -e {0}`
  çalıştırıyor, `pipefail` yok. Doğrulandı: `set -e` altında
  `{ python3 -c 'exit 3'; } | xargs ...` hâlâ `exit 0` veriyor. (0-senaryo
  bulgusu yine de ayakta — o senaryo `pipefail`'dan bağımsız.)
- **"arşivdeki raporlar kullanıcıyı yanıltıyor"** — **geri alındı**. Klasör
  README'si zaten "SÜPERSEDED analizler" başlığını taşıyor ve genel afiş
  bütün klasörü kapsıyor. Gerçek sorun yalnızca iki dosyanın varlığının
  belgelenmemiş olmasıydı; o yukarıda giderildi.

## 🟠 Fixed — VFIO hook'unda `HOST_USER` hiç export edilmiyordu — **KAPATILDI**

- `hooks/qemu:145` → `loginctl terminate-user "${HOST_USER:-localhost}"`
  kullanıyor, ama **`HOST_USER`'ı config'in hiçbir yerinde export eden yoktu**
  (doğrulandı: `vfioHook` yalnızca `PATH`, `HOOK_SETPCI`, `HOOK_FUSER`,
  `HOOK_RTCWAKE` enjekte ediyordu).
- **Etki daraltılmış hâliyle:** `loginctl terminate-seat seat0` (satır 146)
  çoğu senaryoda işi gördüğü için tek kullanıcılı masaüstünde kurulum
  çalışıyordu. Sorun; hesap adı `users.users.localhost.name`'den farklıysa
  **ve** oturum seat0 dışındaysa çıkıyor: oturum kapanmıyor → GPU kilitli →
  `stop_hyprland()` zaman aşımı → rollback → VM açılmıyor.
  (Ayrıca `loginctl` çıktısı `|| true` ile yutulduğu için sebebi log'da görünmüyor.)
- → `configuration.nix` içindeki `vfioHook` gövdesine tek satır eklendi:
  ```nix
  export HOST_USER="${config.users.users.localhost.name}"
  ```
  Hook libvirtd tarafından **tek dosya** olarak çalıştığı için bu export
  `hooks/qemu`'nun geri kalanı boyunca geçerli.

- ⚠️ **Bu, `[1.3.3]`'te önerilen yol DEĞİLDİR** — oradaki öneri
  (`hooks.qemu.vfio.environment`) nixpkgs'te **var olmayan** bir option'dı:
  `virtualisation.libvirtd.hooks` submodule olsa da içindeki `qemu`
  seçeneğinin tipi `attrsOf path`'tir, yani `hooks.qemu.vfio` yalnızca bir
  store yoludur. Burası yeni option istemeden, hook'un kendi gövdesine yazarak
  çözüyor.

- ⚠️ **Aynı düzenleme sırasında ikinci bir hata yakalandı ve düzeltildi.**
  Açıklama yorumunda `hooks/qemu`'nun satırını alıntılarken önce
  `"${HOST_USER:-localhost}"` yazılmıştı. Bu bir **Nix indented string'in
  içidir**: Nix oradaki `${...}`'ı interpolasyon sanır, `HOST_USER:-localhost`
  geçerli bir Nix ifadesi olmadığı için build başlamadan **eval aşamasında
  hata** verirdi. Nix yorumları da string içeriğidir — `#` ile başlaması
  kurtarmaz. `''${` ile kaçırıldı.

  Aynı dosyada yan yana iki farklı `${` var, **karıştırılmamalı**:
  | Yazım | Anlamı |
  |---|---|
  | `export HOST_USER="${config.users.users.localhost.name}"` | `${}` **kasıtlı** — Nix hesaplasın |
  | `loginctl terminate-user "''${HOST_USER:-localhost}"` | `''${` **kaçışlı** — kabuk literal `${` görsün |

  Baştaki iki apostrofu "temizleyen" biri Nix'i kırar. `configuration.nix`
  içine bu ayrımın açıklandığı bir yarıklı uyarı notu bırakıldı.

- ⚠️ **Ve aynı tuzak İKİNCİ KEZ, tam da uyarıyı yazan yorumun içinde
  yakalandı.** İlk uyarı notu, kaçışın ne olduğunu açıklamak için yorum
  satırlarına çıplak `${` yazmıştı — ki bu da bir Nix hatasıdır. Yani dosya
  "bu tuzağa düşmeyin" derken kendi tuzağa düşmüştü. Yorumlar Nix'te ayrışmaz:
  `#` yalnızca kabuk içindir, Nix'e göre düz string içeriğidir.
  → Yorum, kaçış dizisini **yazmadan sözlü tarif edecek** şekilde yeniden
  yazıldı; Nix yorum satırı kavramı olmadığı açıkça belirtildi.

  **Denetim komutu (bu dosyada kaçış sayısı 0 DEĞİL olmalı):**
  ```bash
  # 1) kaçış var mı?
  grep -c "''\${" nixos/configuration.nix      # 0 değil, ≥1 olmalı
  # 2) gövdedeki TÜM interpolasyonları Nix ifadesi mi? (kabuk sözdizimi taşıyan var mı)
  #    gövdeyi çıkar, ''$ kaçışlarını gizle, kalan ${...} içeriklerini listele
  ```
  Uygulanan hâlde: kaçış **1**, gerçek interpolasyon **6**, geçersiz çıplak
  `${` **0**, süslü parantez dengesi **74/74**.

**Ders (proje geneli):** `''${...}` kaçışı bir Nix indented string'ine yazılan
her açıklama için gerekli olabilir, ama açıklamayı yazmanın kendisi aynı
kurala tabidir. Kaçışı örneklerken **metin olarak yazmak yerine tarif etmek**
(iki tek tırnak + dolar) hem güvenli hem okunur.

# [1.3.3] - 2026-10-06

> ⚠️ **Bu bölümün altındaki commit hash'lerinin hepsi tarihseldir.** Hiçbiri
> güncel HEAD değildir. Depo GitHub web arayüzünden tek commit olarak yükleniyor,
> bu yüzden hash her yüklemede değişir; aşağıda geçen `0137b38`, `24cd1ca`,
> `97a1665`, `b993f54`, `602f217`, `0d35833`, `4bc1258d` değerleri **yazıldıkları
> andaki** commit'leri gösterir. Güncel HEAD: **`af7337f`** ("Add files via upload").
> Bu not, geçmiş bölümlerin **anlatı olarak** doğru, ama hash olarak güncelliğini
> yitirmiş olduğunu belgeler; geçmiş kayıtları yeniden yazmadık.

Bağımsız denetim turu #2. Bu turda **CI'ın üç kapısı yerinde yeniden koşuldu**
(Nix 2.35.2 kuruldu), `low_latency_layer` gerçekten indirildi, upstream kaynak
(`low_latency_layer@948a561`, `impermanence@7b1d38`, `lsfg-vk-flake@62aadfc`)
okundu ve impermanence'in gerçekten ne ürettiği `nix eval` ile incelendi.
Bulunanların **tamamı belge katmanındaydı**; kodda P0/P1 düzeltme gerektiren
kırık çıkmadı.

## 🔴 Fixed — projenin gerçek `README.md`'si kaybolmuştu

- **Kök `README.md`, `docs/archive/README.md` dosyasının bir kopyasıydı.**
  37 satır, yalnızca Hyprland satırında tek fark — yani depo GitHub'da
  göründüğünde ilk ekranda *"Arşiv — SÜPERSEDED analizler"* başlığı çıkıyordu;
  projenin ne olduğu, nasıl kurulacağı ve hangi tuşun ne yaptığı hiçbir yerde
  yoktu.
- Döngüsel ölü bağlantı: arşiv README'si *"Gerçek giriş `README.md`
  §Hyprland'da"* diyordu, ama `README.md`'de böyle bir bölüm bulunmuyordu.
- `[1.3.2]`'nin *"README düzeltildi (virt-manager uyarısı, §7b '5 Değer',
  HYPRLAND_CONFIG bölümü)"* kaydı da bu yüzden **kayıp içeriği** anlatıyordu.
- → Kök `README.md` sıfırdan yazıldı: gereksinimler, iki ayrı kurulum yolu,
  VM başlatma, tam tuş kısayolu tablosu, grafik/oyun bileşenleri, özel ayarlar,
  bilinen sınırlar, depo haritası, doğrulama komutları. `KURULUM.md` ile
  çakışmayacak şekilde yazıldı (kurulum detayı orada kalıyor).

## 🟠 Fixed — `home.nix` kalıcılık yorumu ne yaptığını yanlış söylüyordu

- `home.persistence."/nix/persist/home"` yorumu *"yalnızca lsfg-vk shader
  önbelleği korunuyor"* diyordu. **Yanlıştı:** kalıcılaştırılan
  `.config/lsfg-vk/conf.toml` bir önbellek değil, lsfg-vk'nın **yapılandırma**
  dosyasıdır. Upstream `lsfg-vk-flake/module.nix`, `configFile` seçeneğinin tam
  olarak bu yolu beklediğini belgeliyor; shader önbelleği `~/.cache` altındadır.
- Yani kalıcı olan şey oyun başına kare çarpanı ayarları — ve bu, config'in
  `/etc/vulkan/implicit_layer.d` için kendi not düştüğü *"persist dizini ilk
  açılışta boş → gölgeler ve kaybolur"* tuzağının **aynı sınıfı**, ama
  `/etc/vulkan` için düzeltilmiş hâli burada uygulanmamıştı.
- Mekanizma doğrulandı: impermanence bunu Home Manager aktivasyonu değil,
  `local-fs.target`'tan **önce** koşan bir systemd servisi olarak kuruyor
  (`persist-nix-persist-home-home-localhost-.config-lsfg\x2dvk-conf.toml`).
  `mount-file.bash` ilk boot'ta mount noktasına bir symlink kuruyor, HM yazımı
  bu symlink üzerinden yapıyor → dosya kalıcı depoya düşüyor. İlk seferde
  çalışıyor; yorum artık bunu ve `rm -f` ile sıfırlama adımını anlatıyor.
- → Yorum düzeltildi. Davranış **değiştirilmedi** (tasarımın sahibinin
  tercihi); kullanıcıyı yanıltan açıklama gerçeği anlatacak biçimde yeniden
  yazıldı.

## 🟠 Fixed — `KURULUM.md` çalışmayan bir talimat veriyordu

- **`HOST_USER=kullanici sudo virsh start win10`** (eski §9b) **çalışamaz**:
  hook'u **libvirtd** (uzun ömürlü systemd servisi) çalıştırır, `virsh`
  istemcisinin ortamını miras almaz; ayadaki `sudo` da `env_reset` ile ortamı
  temizler. `HOST_USER` config'in hiçbir yerinde tanımlı değil — hook her
  zaman `localhost`'u sonlandırıyor.
- → Talimat kaldırıldı; gerçek durum yazıldı.
- ⚠️ **DÜZELTME (2026-10-08, `[1.3.4]`):** bu maddenin "tek geçerli çözüm
  yolu" olarak verdiği `virtualisation.libvirtd.hooks.qemu.vfio.environment`
  **MEVCUT DEĞİL.** nixpkgs'te `virtualisation.libvirtd.hooks` bir submodule,
  ama içindeki `qemu` seçeneğinin tipi **`attrsOf path`**'tir — yani
  `hooks.qemu.vfio` bir store yoludur, alt-option'ı olamaz. Bu notu uygulamaya
  çalışan kullanıcı `The option ... does not exist` hatası alır ve çözümün
  imkânsız olduğunu sanar. Gerçek çözüm `[1.3.4]`'te uygulandı: `export`
  doğrudan `vfioHook` gövdesine yazılıyor.

## 🟡 Fixed — doküman hataları

- **Üç farklı commit hash'i "güncel kod" diye geçiyordu.** Gerçek HEAD `af7337f`
  ("Add files via upload"); `docs/archive/README.md` ve `DEGISIKLIKLER.md`
  `0137b38`, `CHANGELOG [1.3.2]` ise `24cd1ca` diyordu. Depo GitHub web
  arayüzünden tek commit olarak yüklendiği için hash her yüklemede değişiyor —
  `[1.3.2]` bunu zaten "yapısal" diye not etmişti, ama arşiv belgeleri eski
  hash'i hâlâ şimdiki kod diye sunuyordu. Gerçek HEAD'e hizalandı, artarak
  neden değiştiğini belirten not eklendi.
- **`KURULUM.md` §7b, boş monitör adı için "masaüstü açılmayabilir"**
  diyordu. Boş ad geçerli Hyprland söz dizimidir ve masaüstü **açılır**;
  gerçek etkisi tüm çıkışların workspace 1'e yansılanmasıdır (çok monitörde
  bozuk, tek monitörde zararsız). `home.nix`'teki doğru ifadeyle hizalandı.
- **`KURULUM.md` §6'da `chown "$(id -un)": /mnt/nix/persist/home`** — tırnak
  dışına sıkan `:` `chown kullanici: dosya` demek, yani *"owner'ı kullanıcı yap,
  grubu değiştirme"*. Muhtemelen `$(id -un):$(id -gn)` kastedilmişti. Daha
  önemlisi canlı ISO'da `localhost` kullanıcısı olmadığı için ISO kullanıcısına
  sahiplik veriyordu. Satır kaldırıldı: sahiplik zaten boot'ta
  `systemd.tmpfiles.rules` → `d /nix/persist/home 0755 localhost localhost -`
  kuralıyla düzeltiliyor (`d` mevcut dizinde de mode/owner uygular).
- **`assets/example.conf` diye bir dosya yok.** `README.md:15` ve
  `CHANGELOG [1.3.2]` bunu, *"`$TIME` düzeltmesi doğrulandı"* kanıtı olarak
  gösteriyordu. İddianın kendisi doğru (`nixos/home.nix` → `hyprlockConf`
  → `text = $TIME`), yalnızca kanıt bağlantısı kırıktı. Arşiv README'sindeki
  atıf, gerçek doğrulama yerine (`nixos/home.nix`) yönlendirildi.
- **`docs/archive/README.md` §Hyprland satırı bayattı.** Kök README'de
  2026-10-06 düzeltmesi uygulanmış, arşiv kopyasında eski *"Fiilen
  gerçekleşmiyor"* ifadesi kalmıştı. Arşiv kopyası da gerçekle hizalandı.
- **`home.nix` girintisi yanıltıyordu.** `systemd.user.services` ve
  `home.packages` sütun 0'da başlıyordu; üstlerinde modül attrset'i kapatan
  `};` göründüğü için dosya **yapısal olarak kırık** okunuyordu. Parantez
  dengesi ölçüldü: **parse hatası yok**, yalnızca girinti. Bloklar girintilendi.

## 📝 Yeniden doğrulananlar (değiştirilmedi)

- **CI'ın üç kapısı gerçekten geçiyor** — bu kez bağımsız olarak koşuldu:
  `shellcheck -S warning install.sh nixos/hooks/qemu` → 0; gömülü 7 script →
  0; `nix flake check --no-build` → `all checks passed!` (exit 0).
- **Dördüncü kapı da çalışıyor:** eval sonrası `flake.lock` özeti değişmiyor.
- **`low_latency_layer` sha256'ı doğru.** Gerçek `fetchFromGitHub` build'i
  başarılı (`[1.3.1]`'in iddiasının teyidi).
- **Upstream yorumları doğru.** İndirilen kaynakta: `install(TARGETS … LIBRARY
  DESTINATION ${CMAKE_INSTALL_LIBDIR})`, `install(FILES … DESTINATION
  "${CMAKE_INSTALL_DATADIR}/vulkan/implicit_layer.d/")`, manifest'te
  `disable_environment` var / `enable_environment` **yok**,
  `layer_context.hh` yalnızca 3 ortam değişkeni okuyor. `configuration.nix`'teki
  yorumların tamamı ispatlandı.
- **CHANGELOG iddiaları tutarlı:** Hyprland ailesi sürümleri (0.56.2 / 0.9.6 /
  0.1.8 / 0.4.7 / 0.1.3) tek nixpkgs rev'inden geliyor; 2 Vulkan katmanı aktif
  (3 değil); `@gamemode` `loginLimits`'ten kalkmış; paket tekrarları gerçekten
  temizlenmiş; `HYPRLAND_CONFIG` sabitlenmiş.
- **`install.sh`'in `home.nix` yaması çalışıyor.** Beş değişkenin regex'i gerçek
  dosyada denendi: her biri tam 1 satır eşleşiyor, `monitorOutput` regex'i
  `hyprlandMonitorLine`'i yanlışlıkla yakalamıyor, yamalanmış dosya
  `nix flake check`'ten geçiyor.

## ⚠️ Bilerek dokunulmadı

- **`assets/kitty-.png` (168 KB) ve `assets/wall-.png` (2,88 MB)** — ikisi de
  config'e bağlı değil (`kitty-.png` hiçbir yerde referans edilmiyor; duvar
  kâğıdı `~/Downloads/*.mp4`'e bakıyor) ve birlikte zip'in ~%96'sını oluşturuyor.
  Silmek kullanıcının tercihi; README'de "config'e bağlı değil" diye belirtildi.
- **`low_latency_layer`'ın Reflex/SPOOF_NVIDIA davranışı** — yalnızca kaynak
  okunarak doğrulandı, gerçek bir GPU'da çalıştırılmadı.
- **`hooks/qemu`'daki Navi 2x kurtarma yolu** — `remove` + `rtcwake` + `rescan`
  mantığı kaynaktan doğru, ama RX 6700 XT üzerinde ikinci VM açılışıyla
  test edilmedi.
- **`system.stateVersion = "26.05"`** — kurulumun yapıldığı nixpkgs ile
  tutarlı görünüyor ama sürüm stratejisi (yeni sürüme geçiş prosedürü)
  belgede yok.

# [1.3.2] - 2026-10-06

Bağımsız denetim turu. Bu tur bulguları **çalıştırılarak** doğrulandı: CI'ın iki
shellcheck kapısı yeniden koşuldu (ikisi de geçiyor), gömülü script'ler
`scripts/extract-embedded-scripts.py` ile diske çıkarılıp taranıldı, yeni
eklenen geometri doğrulaması 5 senaryoda test edildi ve `flake.lock` /
`services.lsfg-vk` / `pkgs.wireplumber` iddiaları upstream kaynaktan teyit edildi.

## 🔴 Fixed — Hyprland config'i sessizce gölgelenebiliyordu

- **`hyprland.lua` riski belgelenmiş ama hiç kapatılmamıştı.** README üstünü
  alarmıyla uyarıyor, `docs/archive/README.md` ise aynı konuda "gerçekleşmiyor"
  diye tamamen reddediyordu. İkisi de eksikti. Gerçek mekanizma (v0.56.2
  `Jeremy::getMainConfigPath()`): `HYPRLAND_CONFIG` → `findConfig(...,"lua")` →
  `findConfig(...,"conf")` → `XDG_CONFIG_DIRS` lua, **ilk bulunan kazanır**.
  - README'ın "PATH'te `hyprland.lua` olmamalı" ifadesi **yanlıştı**:
    `findConfig` PATH'e bakmaz, yalnızca `XDG_CONFIG_HOME` / `XDG_CONFIG_DIRS` /
    `/etc/xdg` altına bakar. NixOS'un `/run/current-system/sw/share/hypr` stub'ı
    bu dizinlerde olmadığı için gölgeleme **yapmıyor** — arşivin bu kısmı
    teknik olarak doğruydu.
  - **Kimsenin yazmadığı gerçek tehlike:** config yokken Hyprland kendi örnek
    `hyprland.lua` dosyasını `~/.config/hypr/` altına üretir (NixOS wiki:
    *"On first run, Hyprland will create a configuration file with autogenerated
    defaults in `$XDG_CONFIG_HOME/hypr/hyprland.lua` if it does not exist."*).
    Home Manager activasyonu çalışmadan bir kez Hyprland başlatıldıysa ya da
    config silinip yeniden açıldıysa, **bir sonraki açılışta tüm config
    gölgelenir** — hata, uyarı, log yok.
  - → `home.nix`: `home.sessionVariables.HYPRLAND_CONFIG` ile yol açıkça
    sabitlendi. Değişken tanımlı olduğu için `findConfig` hiç çalışmaz;
    gölgeleme yapısal olarak imkânsız. İki belge de gerçekle hizalandı.

## 🔴 Fixed — CHANGELOG kendi düzeltmesini doğru raporlamamıştı

- **`[1.3.1]` "Paket tekrarları → temizlendi" diyordu, temizlenmemişti.**
  Ölçüldü: `playerctl`, `wev` ve `libnotify` hâlâ hem `systemPackages`'ta hem
  `home.packages`'ta; `pyprland` hem `configuration.nix` hem `flake.nix`'te.
  Yalnızca `hyprpicker` kaldırılmıştı ve `libnotify` hiç bahsedilmemişti.
  → Gerçekten kaldırıldı (tekrar listesi aşağıda), kayıt düzeltildi.
- **`[1.3.1]` "commit hash'leri hizalandı" diyordu, sorun yapısal.** Depo
  GitHub web arayüzünden tek commit olarak yüklenmiş (`24cd1ca Add files vsiz
  upload`); iç hash'ler bir sonraki yüklemede yine değişeceği için "hizalama"
  kalıcı olamaz. Kayıt tarihsel not olarak işaretlendi.
- **`[1.3.1]` dosyanın EN SONUNDAYDI** — `[1.0.0]`'dan sonra. Keep a Changelog
  ters-kronolojik olmalı; en kritik düzeltme (tüm build'i düşüren cmake
  `installPhase` hatası) listede gömülüydü. → Sıra düzeltildi.

## 🟠 Fixed — sessiz başarısızlıklar

- **`mpvpaper` yanlış çıktıda sessizce hiç açılmıyordu.** `mpvpaper.service`
  yalnızca video **dosyasının** varlığını `ConditionPathExists` ile kontrol
  ediyor; `monitorOutput` adını doğrulayan hiçbir şey yoktu. Varsayılan
  `"DP-3"` başka hiçbir makinede doğru olmadığı için unit normal başlıyor,
  mpvpaper "output not found" ile ölüyor ve `Restart=on-failure` 3 saniyede
  bir yeniden başlatıyordu — kullanıcı yalnızca "duvar kağıdı yok" görüyordu.
  → `hyprland.conf`'a `hyprctl monitors` üzerinden çalışan çıkış adı kontrolü
  eklendi.
- **`wuwa-auto.sh` ekran koordinatları sabitlenmişti.** `0,971 2560x438` gibi
  değerler 2560×1440'e göre yazılmıştı; başka bir çözünürlükte ekranın dışına
  taşınca grim ya hata veriyor ya da alakasız bir bölgeyi tarıyordu ve
  kullanıcı gerçek sebebi göremiyordu. → `WUWA_GEOMETRY_MAIN` /
  `WUWA_GEOMETRY_CHOICE` ortam değişkenleri eklendi ve bölgeler
  `hyprctl monitors` boyutuna karşı doğrulanıyor (5 senaryo test edildi:
  doğru ekran / küçük ekran / geçersiz kılma / `hyprctl` yok / bozuk format).
- **`install.sh` GPU PCI adresini hiç doğrulamıyordu.** Girilen metin
  `hooks/qemu` içine olduğu gibi yazılıyordu; "0000:0b:00" ya da boş bir Enter
  geçerli görünüp bozuk bir hook üretiyor, hata ancak çok sonra VM başlatılırken
  sysfs/fuser tarafında çıkıyordu. VM XML senkronundaki Python zaten regex
  ile doğruluyordu, hook tarafı da aynı kuralı uyguluyor. Doğrulandı: geçerli
  giriş kabul, geçersiz girdi yeniden isteniyor, 3 başarısız denemede kurulum
  `exit 1` ile duruyor.

## 🟡 Fixed — dokümantasyon tutarsızlıkları

- **README, `virt-manager` ile VM başlatmayı öneriyordu** — oysa hook
  `loginctl terminate-user` çağırdığı için oturum kendisi kapanıyor. README ve
  `KURULUM.md` §9b artık aynı şeyi söylüyor: TTY veya `systemd-run` kullan.
- **`KURULUM.md` §7b başlığı "5 Değer" diyordu, tabloda 4 satır vardı.**
  `gitName` / `gitEmail` ayrı satırlara bölündü → 5.
- **`nix.settings.auto-optimise-store = true` kaldırıldı.** Nix ≥ 2.19'da store
  zaten zstd ve `nix.optimise` varsayılan olarak zstd kullanıyor; satır
  pratikte hiçbir şey kazandırmıyor, yalnızca ilk rebuild'i uzatıyordu.
- **`docs/archive/README.md`** §'deki Hyprland iddiası yeni gerçekle hizalandı.

## 📝 Doğrulanan doğrular (dokunulmadı)

- **CI'ın iki shellcheck kapısı gerçekten geçiyor** — `install.sh` +
  `hooks/qemu` ve `home.nix`'ten çıkarılan 7 script, `-S warning` ile sıfır uyarı.
- **Extractor 7 script çıkarıyor** ve hepsi `bash -n` söz diziminden geçiyor.
- **`flake.lock` kanonik:** kök `nixpkgs → nixpkgs_2 (7a0f122f5090)`,
  `impermanence` kök `home-manager`'ı takip ediyor, `home-manager_2` node'u yok.
  (İkinci bir `nixpkgs` node'u cachyos-kernel'in kendi girdisi — normal.)
- **`services.lsfg-vk.enable` / `ui.enable` doğru** — upstream
  `pabloaul/lsfg-vk-flake@main` → `module.nix` ile teyit edildi.
- **`pkgs.wireplumber` mevcut** (nixpkgs-unstable, 0.5.18) — `hyprlock.conf`
  içindeki `wpctl` yolu çözülüyor.

## ⚠️ Bilerek dokunulmadı

- **`assets/wall-.png` (2.88 MB)** — 2560×1440 PNG. WebP'ye çevirmek ~200 KB
  kazandırırdı ama bu bir hata değil, bir tercih; kapsam dışı.
- **`hardware-configuration.nix` içindeki gerçek UUID'ler** — makineye özgü
  oldukları için kullanıcının kendi `nixos-generate-config` çıktısıyla
  değiştirilmesi gerekiyor; repo değeri kasıtlı olarak örnek/uygulanabilir tutuluyor.
- **`docs/archive/` (~92 KB, 5 dosya)** — tamamı geçersiz analiz ama
  `docs/archive/README.md` bunu açıkça söylüyor; silmek tarihsel kayıt
  kaybı olurdu. ([1.3.4]: dört raporun tamamı tek tek listelendi ve
  dosyaların kendi başlıklarına da ⛔ afişi eklendi.)
- **impermanence'in `environment.persistence` uyarısı** — mevcut uyarı
  gürültü; susturmanın bedeli daha ağır ([1.2.2]'de denenip geri alındı).

# [1.3.1] - 2026-10-05

Bağımsız analiz turu bulguları. Her madde ya gerçek `nix build` / `nix flake
check` çalıştırılarak ya da upstream kaynak okunarak doğrulandı.

## 🔴 Fixed — TÜM SİSTEM BUILD'İ DÜŞÜRÜYORDU

- **`low_latency_layer` türetmesi derlenmiyordu.** `installPhase` içindeki
  `cmake --install build`, nixpkgs'in cmake setup hook'u `buildPhase` içinde
  cwd'yi `<source>/build`'e düşürdüğü için `<source>/build/build` arıyordu:
  `CMake Error: Not a file: .../source/build/build/cmake_install.cmake`.
  Paket `environment.systemPackages`'te olduğu için bu tek hata
  `nixos-rebuild switch`'i tek başına düşürüyordu.
  → Özel `installPhase` kaldırıldı. Doğrulama: installPhase'li hâl
  **patladı** (%100 derlendi, installPhase'de öldü), installPhase'siz hâl
  **başarılı** ve manifest tam olarak
  `$out/share/vulkan/implicit_layer.d/low_latency_layer.json` yolunda üretildi.
- **`sha256` DOĞRU çıktı.** Gerçek `nix-prefetch-url --unpack` ile hesaplanan
  NAR hash'i `iUdcNnmY4NqaEnhoJUn7KEKTFQrlqo4tYOkLwEhmL+s=` — birebir aynı.
  CHANGELOG'un "hiç test edilmemiş" kaydı artık geçersiz.
- Üretilen manifest doğrulandı: `library_path` mutlak store yolu (RPATH'li .so
  `libvulkan`'ı kendi çözer, `symlinkJoin` gerekmiyor) ve **`enable_environment`
  yok**, `disable_environment` var → katman varsayılan etkin, README'nin
  Reflex iddiası doğru.

## 🟠 Fixed

- **`polkit.service` geri açılmıyordu.** `stop_hyprland()` hem `ollama` hem
  `polkit.service` durduruyor, `start_hyprland()` yalnızca `ollama`'yı geri
  açıyordu. VM kapandıktan sonra polkit otoritesi kalıcı olarak kayboluyor,
  yetkilendirme diyalogları (disk bağlama, ağ değişikliği) hiç açılmıyordu.
  → Geri açılış döngüsü iki servisi de kapsıyor.
- **`install.sh`'ın VM XML senkronizasyonu hiç çalışmıyordu.** `command -v
  python3` kontrolü var, python3 sistemde yok → her kurulumda "python3 yok"
  uyarısı ve `win10.xml`'deki eski PCI adresi kalıyordu. Sonuç: hook yeni
  adrese `vfio-pci` bind ediyor, libvirt eski adresi arıyor → *device not
  found*, sebebi görünmüyor. → `python3` `environment.systemPackages`'a eklendi.
- **`SUPER+SHIFT+S` sessizce boş dönüyordu.** pypr müzik scratchpad'ı `mpv`
  çağırıyor ve yorum "mpv, zaten kurulu" diyordu — kurulu değildi. `mpvpaper`
  kendi unit PATH'inde mpv taşıdığı için duvar kağıdı çalışır, scratchpad
  çalışmazdı. → `home.packages`'a `mpv` eklendi.
- **`vendor_reset` yanlış sırada çalışıyordu.** `bind_vfio`'dan SONRA
  çağrılıyordu; `vfio-pci` bind sırasında zaten reset yapıyor, bind sonrası
  FLR gereksiz ve Navi2x reset bug'ının en çok konuşulan tetikleyicisiydi.
  → Sıra ters çevrildi: reset artık bind'den önce.

## 🟡 Fixed

- **`rtcwake -m mem` kalıcı kilitlenme riski.** Kurtarma fallback'i host'u
  otomatik askıya alıyor; RTC alarmı BIOS'ta kapalıysa bir daha dönmez. Artık
  askıdan önce tty1/tty2'ye görünür uyarı basılıyor.
- **`nixfmt-rfc-style` deprecated.** Gerçek eval uyarısı:
  *"nixfmt-rfc-style is now the same as pkgs.nixfmt"*. → `pkgs.nixfmt`.
- **CI kilitsiz nixpkgs çekiyordu.** `nix run nixpkgs#statix` aynı commit'te
  farklı sonuç verebilirdi. → flake'in kendi devShell'inden çalışıyor.
- **Extractor'da `lines.index()` tuzağı.** Dosyada İLK eşleşen satırı
  döndürüyor; aynı isimli ikinci script eklenirse yanlış blok çıkarılırdı.
  → `enumerate` + indeks.
- **`security.pam.loginLimits`'taki `@gamemode` kuralı ölüydü** (gamemode
  modülü PAM grubu oluşturmuyor, `renice`'i daemon yapıyor). → Kaldırıldı.
- **`vkbasalt` hiç yüklenmiyordu.** `nix eval` ile `environment.etc`
  listelendi: `/etc/vulkan/implicit_layer.d` altında yalnızca 2 manifest var
  (`VkLayer_LS_frame_generation.json`, `low_latency_layer.json`).
  `vkbasalt`'ın manifest'i `/etc`'ye bağlanmıyor, `VK_INSTANCE_LAYERS` /
  `VK_LOADER_LAYERS` / `VK_LAYER_PATH` da hiçbir yerde ayarlanmıyor.
  → Paket listeden kaldırıldı. **CHANGELOG'daki "3 katman aktif" iddiası
  yanlıştı, 2'dir.**
- **Paket tekrarları** (`hyprpicker`, `playerctl`, `wev` hem systemPackages'ta
  hem home.packages'ta; `pyprland` hem configuration.nix hem flake.nix) → temizlendi.

  > ⚠️ **DÜZELTME (2026-10-06): bu kayıt kısmen YANLIŞTI.** Gerçekte yalnızca
  > `hyprpicker` kaldırılmıştı. `playerctl`, `wev` ve `libnotify` hâlâ iki yerde
  > de tanımlıydı (`libnotify` hiç bahsedilmemişti) ve `pyprland` hem
  > `configuration.nix` hem `flake.nix` içinde duruyordu. Gerçekten temizlendi;
  > doğrulama `README.md` ve bu kayıt [1.3.2] bölümünde.
- **CONTRIBUTING ile CI uyumsuzluğu.** Doküman `shellcheck` (varsayılan `style`)
  diyordu, CI `-S warning` kullanıyor. → Hızalandı.
- **check.yml'de tekrar eden yorum bloğu** → kaldırıldı.
- **Dokümanlardaki commit hash'leri gerçekle uyuşmuyordu** (`0d35833`,
  `602f217`; gerçek HEAD `0137b38`) → hizalandı.

  > ⚠️ **DÜZELTME (2026-10-06): bu kalıcı olarak çözülemez.** Depo GitHub web
  > arayüzünden TEK SEFERDE yüklenmiş, dolayısıyla git geçmişi tek bir commit'ten
  > ibaret (`24cd1ca Add files vsiz upload`) ve `0137b38` gibi iç hash'ler bir sonraki
  > yüklemede yine geçersizleşir. Bu satır artık bir referans değil, tarihsel
  > kayıttır — güncel gerçek için `git log` kullanın.

## ⚠️ Bilerek dokunulmadı

- `hyprlandMonitorLine` boş monitör adı — tek monitörde zararsız, `install.sh`
  gerçek çıktıyı yazıyor; yorum artık tuzağı açıkça anlatıyor.
- `fuser` tabanlı GPU-serbest yargısı — `2>/dev/null` yüzünden "dosya yok" ile
  "kimse kullanmıyor" ayrımı yok. Etkisi gerçek ama kapsam dışı.
- `home.persistence` + `xdg.configFile` çakışması — gerçek rebuild gerektiriyor.
- Navi2x reset bug'ı — donanıma özgü, yazılımla garanti edilemez.

# [1.3.0] - 2026-10-05

Bağımsız kod & yapılandırma denetimi. Kaynak: `nixos-hyprland-vfio(4).zip`
@ `0137b38` (gerçek HEAD; belgelerde geçen `0d35833`/`602f217` hash'leri bu repoda hiçbir commit'e karşılık gelmiyordu). Tüm iddialar **kilitli upstream kaynaklarına** karşı doğrulandı
(nixpkgs `7a0f122`, Hyprland `v0.56.2`, hyprlock `v0.9.6`, hyprutils).

## 🔴 Fixed — CI gerçekten doğrulamıyordu

Workflow'un adı `Nix Flake Check` idi ama içinde **tek satır Nix yoktu**:
`nix-installer-action` Nix'i kuruyor, sonra hiç çağrılmıyordu. Tek gate
shellcheck'ti. Bu repo'nun CHANGELOG'unun tamamı option seviyesinde
düzeltmelerden oluşuyor (olmayan option, yanlış libvirt yolu, ABI/sürüm
 kayması) ve **hiçbiri** kapı altında değildi.

- `nix flake check --no-build` eklendi (`working-directory: nixos`).
  Derleme yapmaz, tüm modül sistemini eval eder — option hatalarını yakalar.
- `statix` / `deadnix` eklendi (gate değil, uyarı seviyesi).

## 🔴 Fixed — `flake.lock` `flake.nix`'i yalan söylüyordu

`flake.nix`'e `impermanence.inputs.home-manager.follows` eklenmişti ama
lock hâlâ `impermanence → home-manager_2` (`c47b2cc64a62`) çözüyordu, kök
ise `7b4c5ec4beda` kullanıyordu — yani düzeltilen "iki HM sürümü aynı anda
modül sisteminde" hatası **lock'ta hâlâ kodluydu**. Çalışmasının tek
sebebi `nixos-rebuild`'ın lock'u sessizce yeniden yazmasıydı; readonly
flake veya `--no-update-lock-file` ile patlardı.

- `home-manager_2` node'u kaldırıldı, `impermanence.inputs.home-manager`
  artık kök `home-manager`'ı takip ediyor.

## 🟠 Fixed — `install.sh` git deposunu yerinde değiştiriyordu

`vm-xml/win10.xml` `sed`/python ile **değiştiriliyor**, sonra değişiklik
`git update-index --skip-worktree` ile saklanıyordu. Bu "repo = değişmez
şablon" değişmezini bozuyor, sonraki `git pull`'da merge conflict üretiyor
ve `git status` yalan söylüyordu. `hooks/qemu` için de aynı desen vardı.

- Patch'lenmiş XML artık doğrudan `/var/lib/libvirt/win10.xml` altına
  yazılıyor; **kaynak repo dosyasına dokunulmuyor.**
- Tüm `git update-index` çağrıları kaldırıldı.

## 🟠 Fixed — 3+ PCI passthrough'ta XML senkronu sessizce atlanıyordu

`counter[0] != 2` ise python `sys.exit(1)` veriyordu — **kullanıcıya hiçbir
uyarı gitmeden**. 2 GPU + NIC geçiren bir kurulumda hook yeni PCI adresine
bind olup libvirt eski adresi arıyor, yani "device not found" — ve sebebi
görünmüyordu.

- 0 hostdev → gerçek hata, çıkılıyor.
- 3+ hostdev → ilk 2'si yazılıyor, **kaç tanesinin elle düzenleneceği
  `stderr`'e basılıyor** ve doğrulama komutu gösteriliyor.

## 🟡 Fixed — Ollama isteminde literal `\n`

`jq --arg pr "EN: $text\nTR:"` — jq `--arg` C kaçışlarını yorumlamaz, model
tek satırda `EN: …\nTR:` görüyordu. Artık `printf 'EN: %s\nTR:'` ile gerçek
satır sonu üretiliyor.

## 🟡 Fixed — `SUPER+SHIFT+T` çevirisi ilk satırda kesiliyordu

`| { read -r _t; notify-send … "$_t"; }` — `read -r` yalnızca ilk satırı
okur, çok satırlı çevirinin tamamı kayboluyordu. Artık tüm çıktı
değişkende toplanıyor.

## 🟡 Fixed — Canlı duvar kağıdı sessizce hiç açılmıyordu

`mpvpaper.service` `ConditionPathExists = ${wallpaperVideo}` taşıyor. Dosya
yoksa systemd unit'i **sessizce** atlar — ne hata ne duvar kağıdı.
`install.sh` yalnızca yol soruyor, videoyu indirmiyordu.

- Oturum açılışında görünür `notify-send -u critical` kontrolü eklendi.

## 🟡 Fixed — `wuwa-auto.sh` hiç dinlenmiyordu

Kalıcı `while true` döngüsü 3 saniyede bir 2× `grim` + 2× `mogrify` +
2× `tesseract` çalıştırıyordu — tüm gün, oyun oynanırken bile. Tesseract
ağır bir CPU yükü.

- Hiçbir bölgede değişiklik yoksa bekleme 3s → 30s'e kademeli çıkıyor,
  ilk değişiklikte anında 3s'ye dönüyor.

## 🟡 Fixed — Waybar'da boşaltılmış Nerd Font ikonları

`pulseaudio` (`headphone`, `phone`, `portable`, `car`) ve `mpris`
(`spotify`, `chromium`) için glyph'ler boş string'e düşmüştü; komşular
duruyordu. Kulaklık/Spotify ikonu hiç çizilmiyordu. Dolduruldu.

## 🔧 Removed / Moved

- **Kök `shell.nix` silindi.** İkinci bir geliştirme ortamıydı: `<nixpkgs>`
  channel + `nixpkgs-fmt`, `flake.nix`'teki `devShells` ile (`nixfmt-rfc-style`)
  çelişiyordu. Artık tek yol: `nix develop ./nixos`.
- **`ANALIZ-2026-10-05.md` → `docs/archive/`** (zip (3) @ `97a1665` için
  yazılmıştı, bu kod `0137b38` — en "güncel" görünen belge en eski kodu
  anlatıyordu).
- **`nixos-hyprland-vfio-analiz.md` → `docs/archive/`** (v2 raporu).
- **Bu iki dosya (`FIXES-2026-10-05.md`, `FIX-MANIFEST.md`) repoda YOK.**
  CHANGELOG, `README.md` ve `docs/archive/README.md` onları "güncel kaynak"
  olarak gösteriyordu ama ne commit'te ne de zip içinde bulunuyorlar.
  (Kök neden: `F-İX-MAN-İFEST.md` adındaki dosya Windows'ta yapılan zip'te
  Türkçe büyük noktalı İ (U+0130) CP1252'ye çevrilip `¦` (0xA6) olmuş,
  ASCII adıyla eşleşmemişti.) Üç referans da artık mevcut olmayan dosyayı
  göstermiyor; düzeltme kaydı burada tutuluyor.

## 📝 Doğrulanan doğrular (dokunulmadı)

- `virtualisation.libvirtd.hooks.qemu.vfio` gerçek bir option; `libvirtd.nix:517`
  → `ln -s --force … /var/lib/libvirt/hooks/qemu.d/vfio`. Yorumdaki
  "libvirt `/etc/libvirt/hooks`'i okumaz" tespiti **doğru**.
- `security.pam.loginLimits` value'su string olabilir (`oneOf [ str int ]`).
- hyprlock 0.9.6 `$TIME` / `$USER`'ı destekliyor (`IWidget::formatString`,
  `IWidget.cpp:200,208`) ve otomatik tazeliyor.
  > **DÜZELTME (2026-10-06):** bu satır `assets/example.conf:79`'a atıf yapıyordu.
  > **Böyle bir dosya repoda yok** (`assets/` yalnızca iki PNG içeriyor), yani
  > kanıt bağlantısı kırıktı. Gerçek doğrulama yeri `nixos/home.nix` →
  > `hyprlockConf` bloğundaki `text = $TIME` satırıdır; iddianın kendisi doğrudur.
- `hyprland.conf` kullanılıyor, yok sayılmıyor. `Jeremy::getMainConfigPath()`
  önce `.lua` arıyor ama `Hyprutils::Path::findConfig` yalnızca
  `XDG_CONFIG_HOME` / `XDG_CONFIG_DIRS` / `/etc/xdg` altına bakıyor;
  NixOS'un `pathsToLink = [ "/share/hypr" ]` ile koyduğu stub
  `/run/current-system/sw/share/hypr/hyprland.lua` bu dizinlerde **değil**.
- Gömülü script extractor çalışıyor (7 script çıkarılıyor).

## ⚠️ Hâlâ açık / doğrulanamadı

- `low_latency_layer` `sha256`'ı hiç test edilmemiş ve CI ona dokunmuyor.
  Bu paket cachix'te yok → ilk kurulumda kaynaktan derlenir; build
  başarısız olursa `environment.systemPackages` yüzünden **tüm sistem
  build'i** düşer. Elle doğrulanamadı (build çalıştırılamadı).
- `hyprlandMonitorLine` default'u hâlâ `monitor = ,preferred,auto,1`
  (boş ad). Tek monitörde zararsız, çok monitörde anlamsız. Sadece
  `install.sh` dolduruyor.
- ~~Aynı anda 3 Vulkan implicit layer aktif (`lsfg-vk` + `low_latency_layer`
  + `vkbasalt`).~~ **DÜZELTİLDİ (2026-10-05): iddia yanlıştı, 2 katman
  aktiftir.** `nix eval` ile `environment.etc` listelendi: yalnızca
  `vulkan/implicit_layer.d/VkLayer_LS_frame_generation.json` ve
  `vulkan/implicit_layer.d/low_latency_layer.json` yazılıyor. `vkbasalt`
  `systemPackages`'ta vardı ama nixpkgs onun manifest'ini `$out/share/...`
  altına koyar, `/etc/vulkan`'a bağlayan hiçbir şey yoktu ve
  `VK_INSTANCE_LAYERS`/`VK_LOADER_LAYERS`/`VK_LAYER_PATH` hiçbir yerde
  ayarlanmıyordu → **katman hiç yüklenmiyordu**. Paket listeden kaldırıldı.
  Kalan 2 katmanın (`lsfg-vk` + `low_latency_layer`) kombinasyonu hâlâ
  test edilmemiş ve default olarak açık.
- `power-profiles-daemon` ↔ `ananicy-cpp` ↔ `gamemode` üçlüsü CPU
  önceliğinde birbirine yazıyor; sıra garantisi yok. Kasıtlı bırakıldı,
  `configuration.nix`'te yorumlandı.
- `mpvpaper-watchdog` + gamemode `custom.start/end` çift yönetimi sürüyor.

---

# [1.2.2] - 2026-10-04

## 🔴 Fixed — CI gerçekten doğrulamıyordu

- **CI'ın "Flake structure check" adımı boştu.** `nix flake show`
  modül sistemini **değerlendirmez**. Kanıtlandı: `configuration.nix`'e
  `services.tamam-boyle-bir-option.enable = true;` eklendi →
  `nix flake show` exit 0 (geçti), `nix eval …toplevel.drvPath` exit 1
  ("option does not exist"). Yani yanlış/silinmiş option, yanlış tip,
  Home Manager modül hatası ve assert ihlali CI'dan **geçiyordu**.
  4bc1258d'de `flake check` → `flake show` değişikliği `--no-build`
  sorununu çözdü ama kazara tüm eval kapsamını sildi.
  → Adım gerçek değerlendirmeye çevrildi:
  `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath`
  (build çalıştırmadan ~2.5 dk). `README.md` / `CONTRIBUTING.md` de aynı
  komuta hizalandı — üçü artık birbiriyle tutarlı.

## 🟠 Fixed — sıfırdan kurulumu kilitleyen hata

- **KURULUM.md, kurulumu bitiren kullanıcıyı kilitli bırakıyordu.**
  `configuration.nix:321` → `hashedPasswordFile = "/etc/nixos/hashedPassword"`.
  Bu dosya repoda tutulmuyor (`.gitignore`) ve `nixos-install` sırasında
  **hata vermiyor** — sadece activation'da
  `warning: password file … does not exist` basıp `/etc/shadow`'a
  `localhost:!:1:::::` yazıyor, yani tuigreet ile masaüstüne giriş
  imkânsız, kullanıcı root konsoluna düşüyor.
  (`update-users-groups.pl` bu yolda `die` değil `warn` kullanıyor.)
  → KURULUM.md §8'e `mkpasswd --method yescrypt` komutu + açıklama eklendi.
  Aynı bölümde SSH'in varsayılan olarak kapalı olduğu da vurgulandı.

## 🟠 Fixed — `qemu.runAsRoot = false` sahiplik sorunu

- **`virsh start win10` "Permission denied" ile başlayabilirdi.**
  `qemu.runAsRoot = false` iken libvirt disk/NVRAM dosyalarını
  `qemu-libvirtd` ile açıyor; `runAsRoot = true` döneminden kalma dosyalar
  root'a ait kalırsa açılamıyor. NixOS'un kendi option açıklaması da
  bunu söylüyor. Bu kontrol runtime listesinde hiç yoktu.
  → `systemd.services.libvirtd-qemu-ownership` oneshot servisi eklendi
  (`before = [ "libvirtd.service" ]`), her boot'ta
  `/var/lib/libvirt/{images,qemu}` sahipliğini düzeltir.

## 🟠 Fixed — Hyprland ABI karışıklığı (yön ters kaydedilmişti)

- **CHANGELOG "Hyprland 0.55.0 nixpkgs'tan ~4.5 ay geride" diyordu;
  gerçek tablo ters.** Nixpkgs (nixos-unstable, `7a0f122`) Hyprland
  **0.54.3** veriyor; overlay ile compositor 0.55.0'a zorlanıyordu.
  Gerçek risk: `hyprlock 0.9.5`, `hypridle 0.1.7`, `hyprpicker 0.4.6`,
  `hyprpolkitagent 0.1.3`, `xdg-desktop-portal-hyprland 1.3.12` hepsi
  0.54.3'e derlenmiş — 0.54-ABI'lı istemciler 0.55 compositor'a
  konuşuyordu. Portal sessizce hiçbir şey sunmazsa hiçbir hata da
  görünmez.
  → `hyprland` flake input'u ve overlay kaldırıldı; tüm Hyprland ailesi
  tek nixpkgs rev'inden geliyor. Geri almak için flake.nix'deki not.

## 🟡 Fixed — eval uyarıları ve küçük yanlışlar

- **`environment.persistence` uyarısı — denendi, işe yaramadı, geri alındı.**
  Her `nixos-rebuild`'de "Neither /var/lib/nixos nor any of its parents are
  persisted / users are missing a uid" uyarısı basılıyor. Rapor bunu
  `environment.persistence."/var/lib/nixos"` tanımıyla çözmek öneriyordu;
  **gerçek `nix eval` ile denendi ve yanlış olduğu kanıtlandı:**
  1) Tanım eklendiği hâlde uyarı **yine basılıyor** (sessizleşmiyor).
  2) Impermanence'in güncel sürümünde `method` option'ı kaldırılmış;
     persistence alt modülü zorlanınca
     `The option 'method' can no longer be used since it's been removed`
     hatası veriyor — yani susturmanın bedeli daha ağır.
  → Tanım **eklenmedi**; durum `configuration.nix` içinde nedeniyle
  birlikte belgelendi. Gerçek etkisi düşük: UID'ler `update-users-groups.pl`
  tarafından `/etc/passwd`'deki ilk boş slottan seçildiği için pratikte
  sabit kalıyor. Bu bir gürültü uyarısı, build'i etkilemiyor. Sessizleştirmenin
  tek yolu impermanence modülünü tamamen kaldırmak.
- **`xorg.xev` deprecated** → `xorg.xev` kaldırıldı (`wev` zaten vardı ve
  aynı paket). Eval uyarısı gitti.
- **`home.nix` yanlış nixpkgs rev'i atıyordu** (`3b4545497180` = cachyos
  kernel'in kendi nixpkgs'i). Kök rev `7a0f122f5090` olarak düzeltildi.
- **`install.sh` git çalışma ağacını kirletiyordu.** `sed` ile
  `hooks/qemu` değiştiriliyor, sonraki `git pull` conflict veriyordu.
  → Değişiklikten sonra `git update-index --skip-worktree hooks/qemu`
  uygulanıyor (başarısız olursa uyarı basılıyor).
- **`home.persistence."/nix/persist/home"` yanıltıcı görünüyordu.**
  İlk okumada bu anahtarın `/nix/persist`'le çakıştığı ve
  `/home/localhost/nix/persist/home` olduğu düşünüldü. Gerçek eval ile
  test edildi: anahtar `$HOME`'a göre yorumlanıyor **ve mutlak yol
  olmak zorunda** — göreli yola çevirmek denemesi
  `not of type 'absolute path'` hatasıyla eval'i düşürdü, yani
  **orijinal değer doğruymuş**. Kod değiştirilmedi, sadece yanlış
  anlaşılmayı önleyen bir yorum eklendi (`/nix/persist` ile ilgisi
  yoktur; impermanence'in kendi "nix" manager'ı onu yönetir).
- **Hardcoded `/home/localhost/...` yolları** (waybar sıcaklık scripti,
  `mpvpaper-watchdog` ExecStart, mpvpaper video yolu)
  → `${config.home.homeDirectory}` ile değiştirildi.
- **`#reference:9` anlamsız yorumu** kaldırıldı.
- **CI kapısının gücü gerçek eval ile kanıtlandı:** yeni `nix eval` adımı
  bu depoda gerçekten çalışıyor. Bu sırada `home.persistence` anahtarını
  yeniden adlandırmayı denedim; modül `not of type 'absolute path'`
  hatasıyla **değerlendirmeyi düşürdü** → orijinal değer doğruymuş,
  değişiklik geri alındı. Aynı hata `nix flake show` ile **geçiyordu**,
  yani kapının düzeltilmesi kanıtlanmış oldu.
- **Sonuç: tüm değişikliklerden sonra flake gerçekten eval edildi ve
  `toplevel.drvPath` üretildi.** `xorg.xev` uyarısı da bu sırada kayboldu.
- **`hardware-configuration.nix` kendi kendisiyle çelişiyordu:**
  "⚠️ @snapshots'ı BURAYA mount ETMEYİN" yazıp hemen altında mount
  ediyordu. Yorum netleştirildi (kastedilen: `/home/.snapshots` için
  `subvol=@snapshots` **yazmayın**, gömülü `@home/.snapshots` kullanın).
- **README "`install.sh` dosyaları düz `/etc/nixos/`'a kopyalıyor"**
  diyordu; artık `${NIXOS_DIR}/nixos` altına kopyalıyor. Düzeltildi.
- **mpvpaper'ı iki yöneten var** (`programs.gamemode.custom` ve
  `mpvpaper-watchdog`). İkisi de `systemctl start/stop` kullandığı için
  idempotent, ama oyun sırasında watchdog bir "start" atarsa duvar kağıdı
  erken geri gelebilir. Çakışma yorumda belgelendi, tek kaynak isteyenler
  için hangi satırların silineceği yazıldı.

## 📝 Not

`authorizedKeys.keys` boş bırakıldı (bakımcı anahtarı kaldırılmaya devam
etti) ama bu artık "kişisel tercih" değil, gerçek bir **P1**: config'i
güncelleyen kişinin en olası acil erişim kanalı SSH ve `switch` sonrası
o kanal kapanıyor. `configuration.nix` ve README'ye uyarı eklendi; anahtar
kullanıcının kendi public key'i olduğu için koda gömülemedi.

---

# [1.2.1] - 2026-10-04

## 🐛 Fixed — sessiz hatalar (kaynakla doğrulandı)

- **`LOW_LATENCY_LAYER = "1"` sessiz bir no-op'tu.** Pinned rev (`948a561`)
  yalnızca şu üç değişkeni okuyor: `LOW_LATENCY_LAYER_REFLEX`,
  `LOW_LATENCY_LAYER_SPOOF_NVIDIA`, `LOW_LATENCY_LAYER_FORCE_DECOUPLED`
  (`src/layer_context.hh:52-61`). `LOW_LATENCY_LAYER` diye bir değişken
  **yok**. Bu satır 1.2.0'da eklenmişti ve hiçbir işe yaramıyordu — 1.2.0'ın
  düzelttiği `ENABLE_LOW_LATENCY_LAYER` hatasının aynı sınıfı.
  → Satır kaldırıldı, nedeni yorumda belgelendi.
  (`LOW_LATENCY_LAYER_REFLEX = "1"` kaldı ve DOĞRU; o gerçekten okunuyor.)

- **Tekerlek binding'leri hiç çalışmıyordu — 1.2.0 yorumu ters yöne bakıyordu.**
  1.2.0 bunu "dwindle uyumu belirsiz, runtime'da doğrulanmadı" diye kaydetmişti.
  Hyprland v0.55.0 kaynağı bunu kesinleştiriyor:
  - `scroll:down` / `scroll:up` **hiç üretilmiyor**.
    `KeybindManager::onAxisEvent` (`src/managers/KeybindManager.cpp:407-434`)
    tekerleği EKSEN olayı olarak alıp `e.delta<0` için `"mouse_down"`,
    `e.delta>0` için `"mouse_up"` ismiyle `handleKeybinds()` çağırıyor.
  - `layoutmsg` komutları yanlıştı: dwindle'in kabul ettiği alt komutlar
    yalnızca `togglesplit` / `swapsplit` / `rotatesplit` / `movetoroot` /
    `preselect` / `splitratio` (`src/layout/algorithm/tiled/dwindle/DwindleAlgorithm.cpp:640-733`).
  - `cycleprev` **hiçbir dispatcher değil**; v0.55.0 listesinde yalnız
    `cyclenext` var (`src/managers/KeybindManager.cpp:37-105`).
  → `bind = $mainMod, mouse_down, cyclenext` /
    `bind = $mainMod, mouse_up, cyclenext prev`.

- **`$mainMod + M` (monocle) hatası veriyordu.** `layoutmsg set monocle`
  dwindle'da "Unknown dwindle layoutmsg" döndürür. v0.55.0'in legacy
  dispatcher listesinde çalışma zamanında layout değiştiren **hiçbir komut
  yok**. Monocle yalnızca `workspace = N, layout:monocle` kuralıyla ya da
  `hyprwm-community/workspacelayout` plugin'iyle seçilebilir.
  → Tuş bilinçli olarak bağlı bırakıldı, seçenekler yorumda.

- **`bindm = $mainMod, mouse:272/273` bozuk DEĞİLDİ — yanlış şüphelenmişti.**
  272/273 = `BTN_LEFT` / `BTN_RIGHT` (0x110 / 0x111, `input-event-codes.h`),
  yani gerçek buton kodları; `onMouseEvent` onları `"mouse:<code>"` adıyla
  tetikliyor. SUPER+sol/sürükle = movewindow, SUPER+sağ/sürükle = resizewindow
  çalışıyor. Tekerlek binding'leriyle karışmıyor (anahtar adları farklı).
  → Dokunulmadı, yalnızca neden çalıştığı yorumlandı.

- **pyprland config yolu yanlış dosyadaydı ve yorumu da ters yazılmıştı.**
  pyprland 3.4.4 (`src/constants.py:45-47`):
  `CONFIG_FILE = ~/.config/pypr/config.toml` (kanonik) ·
  `LEGACY_CONFIG_FILE = ~/.config/hypr/pyprland.toml` (eski) ·
  `OLD_CONFIG_FILE = ~/.config/hypr/pyprland.json` (çok eski).
  1.2.0 kanonik yola yazmış, üstelik "pypr/config.toml pyprland tarafından
  okunmaz" diye ters yönde açıklama eklemişti. Legacy dosya okunmaya
  devam ediyor ama her açılışta "Config at legacy location" uyarısı ve
  ekran bildirimi basıyor (`src/config_loader.py:173-185`).
  → `pypr/config.toml` + doğru açıklama.

- **`install.sh` artık yalan söylüyordu.** `gpuPCI` / `gpuAudio`
  değişkenleri 1.2.0'da silinmişti, ama script hâlâ onları
  `configuration.nix`'te sed'lemeye çalışıp `"GPU PCI addresses set."`
  logluyordu — sed hiçbir şeyi değiştirmiyor, kullanıcı ise doğru
  yaptığını sanıyor. → Ölü blok kaldırıldı (gerçek hedef zaten
  `hooks/qemu`'daki `GPU_PCI`/`GPU_AUDIO`).

- **`install.sh` tek P0 blocker'ı karşılamıyordu.**
  `fileSystems."/home/.snapshots"` `neededForBoot = true` olduğu için alt
  hacim diskte yoksa boot acil kipine düşüyor, ama installer bu adımı hiç
  yapmıyordu. → `btrfs subvolume create /home/.snapshots` installer'a eklendi
  (zaten varsa atlar, `/home` btrfs değilse uyarır).

- **CI'daki shellcheck adımı hiçbir şey yakalamıyordu.** Adım `REPORT
  STEPS` altında `continue-on-error: true` ile çalışıyordu. Ayrıca
  gate'e alınmadan önce hook'ta iki uyarı vardı (`VFIO_PATH` kullanılmıyor,
  döngü sayacı kullanılmıyor — SC2034), yani "sıfır riskli" değildi.
  → Uyarılar giderildi, adım `GATE STEPS`'e taşındı ve shellcheck
  kurulu değilse kendini kuracak şekilde yazıldı.

- **Reboot adımı hiçbir yerde yoktu.** `iommu=pt`, `amd_iommu=on`,
  `amdgpu.ppfeaturemask` kernel parametreleri `switch` ile uygulanmaz.
  Reboot olmadan yapılacak VFIO testi IOMMU'suz olur.
  → `install.sh` son checklist'ine `dry-activate → switch → reboot` eklendi.

## 📝 Corrected — 1.2.0'ın yanlış kaydettiği iki madde

- `argos-translate` **eklenmedi, kaldırıldı.** 1.2.0 "hiçbir `.nix`
  dosyasında tanımlı değildi → eklendi" diyor; oysa nixpkgs'ta yok ve
  `environment.systemPackages`'ten çıkarıldı. `wuwa-auto.sh` hâlâ
  `argos-translate` çağırıyor, paket olmadığı için `translate_fast()`
  her zaman sessizce başarısız oluyor ve her çeviri Ollama'ya düşüyor.
  (README §183 doğruydu, CHANGELOG yanlıştı.)
- README'nin repo ağacında `gemma-modelfile` / `wuwa-modelfile` listeleniyordu;
  ikisi de 1.2.0'da silinmişti. → Ağaç güncellendi.

## 🧹 Removed — ölü değişken

- `hooks/qemu`: `VFIO_PATH` tanımlıydı ama hiç okunmuyordu (shellcheck
  SC2034). Kaldırıldı.

## ⚠️ Hâlâ runtime'da doğrulanmamış

- `nixos-rebuild switch` hiç çalıştırılmadı.
- Hook'un gerçekten çağrıldığı ve GPU'yu vfio-pci'ye bağladığı görülmedi.
- RX 6700 XT ikinci VM başlatma testi yapılmadı (Navi 22 `gnif/vendor-reset`
  destek listesinde değil).
- `low-latency-layer` derivation'ının `sha256`'ı **hiç test edilmemiş**: CI'daki
  `nix flake show` hiçbir şey build etmiyor, `nix-instantiate --parse` yalnız
  syntax kontrol ediyor. Hash yanlışsa ilk gerçek derlemede (yani ilk
  rebuild'da) patlar.
- `rtcwake -m mem` gerçek S3 mü, BIOS'a bağlı.

---

# [1.2.0] - 2026-10-03

## 🔴 Fixed — çalışmayan çekirdek işlevler

- **VFIO hook'u hiç çalışmıyordu.** `environment.etc."libvirt/hooks/qemu"`
  ile `/etc/libvirt/hooks/qemu` altına kopyalanıyordu. libvirt hook'u yalnızca
  `SYSCONFDIR/libvirt/hooks` altından arar (`virhook.c:41`:
  `#define LIBVIRT_HOOK_DIR SYSCONFDIR "/libvirt/hooks"`), nixpkgs ise libvirt'i
  `--sysconfdir=/var/lib` ile deriyor (`package.nix:310`) → gerçek yol
  **`/var/lib/libvirt/hooks/qemu.d`**. `/etc` fallback'i **yok** (`virhook.c`'de
  `getenv` geçişi 0, yol override edilemez). `virHookCheck()` yalnızca iki yol
  deniyor: `<diz>/qemu` ve `<diz>/qemu.d/`.
  Sonuç: hook çağrılmıyor → amdgpu unbind olmuyor, vfio-pci bind olmuyor,
  greetd durmuyor. Üstelik `win10.xml`'de `managed="no"` olduğu için libvirt de
  devreye girmiyordu. **GPU'yu yöneten hiçbir şey kalmıyordu.**
  → `virtualisation.libvirtd.hooks.qemu.vfio` kullanılıyor.

- **Hook shebang'i kırıktı.** `#!/usr/bin/env bash` + `libvirtd.service`'in
  PATH'i yalnızca `qemu + netcat + swtpm` içeriyor (`libvirtd.nix:555-560`) →
  `env bash` bash'ı bulamıyor, script hiç başlamıyordu. Hook'taki
  `mkdir/date/seq/sleep/basename/readlink/systemctl` çağrıları da PATH'e
  bağımlıydı.
  → `pkgs.writeShellScript` ile store-path shebang + `export PATH` (coreutils,
  systemd). `setpci/fuser/rtcwake` zaten mutlak yolda çağrılıyordu.

- **Reflex / low-latency katmanı hiç yüklenmiyordu.** Pinned rev `948a561`
  upstream manifestinde `enable_environment` **içermiyor** (bu rev'de katman
  varsayılan olarak açık). Repodaki elle yazılmış manifest ise
  `ENABLE_LOW_LATENCY_LAYER` ekliyordu; o değişken **hiçbir yerde set
  edilmiyordu**, dolayısıyla Vulkan loader katmanı sessizce atlıyordu.
  Manifest ayrıca yanlış katman adı (`VK_LAYER_ishitatsuyuki_…` vs upstream
  `VK_LAYER_KORTHOS_low_latency`), yanlış sürümler (api `1.3.261`/impl `1` vs
  `1.3.0`/`3`) ve **eksik `functions` eşlemesi** içeriyordu.
  → Özel manifest ve `installPhase` `substitute` bloğu kaldırıldı; upstream'ın
  (cmake `install` kuralı) kurduğu manifest kullanılıyor.

- **WuWa / otomatik çeviri kısayolları hiç çalışmıyordu.**
  `pkill -f wuwa-auto.sh || …/wuwa-auto.sh` — Hyprland `exec`'i
  `/bin/sh -c '<satır>'` ile çalıştırır, kabuğun komut satırı deseni içerir ve
  `pkill -f` **kendi üst kabuğunu öldürür**; `||` fallback'i asla çalışmaz.
  Sandbox'ta yeniden üretildi. (`[w]` hilesi de çalışmaz: aynı satırdaki
  fallback yolu deseni eşleştirir.)
  → Ayrı `toggle-wuwa.sh` / `toggle-auto-translate.sh` betikleri. Bu desen
  sandbox'ta T1/T2/T3 olarak test edildi (başlatıyor, durduruyor, `sh -c`
  üzerinden de çalışıyor).

- **`/home` snapper çalışmıyordu.** NixOS snapper modülü her `SUBVOLUME` için
  içinde `.snapshots` alt hacmi istiyor (`snapper.nix:51-52`). `hardware-
  configuration.nix` yalnızca `/.snapshots` bağlıyordu →
  `snapper -c home list` başarısızdı.
  → `fileSystems."/home/.snapshots"` eklendi (`subvol=@home/.snapshots`).
  ⚠️ Rebuild ÖNCESİ `sudo btrfs subvolume create /home/.snapshots` gerekir.

- **Sistemde DNS çözümlemesi yoktu.** `services.nextdns` config ID'si
  `"xxxxxx"` idi (NextDNS docs'unun örnek placeholder'ı), üstelik
  `networkmanager.dns = "none"` + `nameservers = [127.0.0.1, ::1]` ile tüm
  çözümleme nextdns'e bağlıydı. Nextdns başlamazsa **hiçbir DNS yoktu**.
  → NextDNS devre dışı, DNS NetworkManager'ın yönetiminde. Kullanmak isteyenler
  için gerçek config ID'siyle nasıl açılacağı yorumda.

- **SSH uzaktan kilitleniyordu.** `PasswordAuthentication = false` +
  `authorizedKeys` içinde **proje bakımcısının** açık anahtarı. Kurulumu yapan
  kişinin kendi anahtarı yoktu → SSH ile giremiyordu, ama bakımcınınkiyle
  girebiliyordu.
  → Anahtar listesi boşaltıldı, kullanıcı kendi anahtarını ekleyecek.

## 🐛 Fixed — diğer

- `vm-xml/win10.xml`'de `<topology>` yoktu. `<cpu>` altına
  `<topology sockets="1" cores="6" threads="1"/>` eklendi (libvirt ≥ 0.7.5'te
  `<cpu>` altında tanımlanır; `<vcpu>` içine yazmak ESKİ biçimdir). Ayrıca
  `<vcpu current="6">`.
- `win10.xml` içindeki 3 USB hostdev (`2a7a:8a47`, `05ac:024f`, `1532:0098`)
  kişiye özel cihazlardı; başka bir makinede **VM başlamıyordu**.
  Yorum satırına alındı.
- `mpvpaper-watchdog` systemd PATH'inde `awk` yoktu, script `awk` kullanıyordu
  → `pkgs.gawk` eklendi.
- `mpvpaper`, `mpvpaper-watchdog` ve `gamemode-notify` hem `hyprland exec-once`
  hem systemd tarafından tetikleniyordu (watchdog için iki instance → yarış
  koşulu) → `exec-once` kaldırıldı, tek kaynak systemd.
- `RADV_ANTILAG=1` kaldırıldı (Mesa değişkeni değil; katman `VK_AMD_anti_lag`'ı
  kendisi sunuyor). `RADV_PERFTEST` `gpl,nggc` → `gpl` (`nggc` GFX10.3'te
  zaten varsayılan, etkisiz).
- `hyprlock.conf`'ta geçersiz `auth-msg` widget'ı kaldırıldı.
- rofi `-theme arthur` kaldırıldı (tema repoda hiç yoktu).
- `MangoHud.conf` ve `conf.toml` (lsfg-vk) **hiçbir yere deploy edilmiyordu**,
  oyunlarda o ayarlar hiç uygulanmıyordu → `home.nix` içine alındı.
  `conf.toml`'daki `exe = "Genshin"` → `"GenshinImpact"`.
- `pypr` config'i yoktu, `pypr toggle term/music/filemanager` tanımsızdı →
  `~/.config/hypr/pyprland.toml` oluşturuldu (pyprland resmi konumu:
  scratchpad bölümleri `[scratchpads.<ad>]` biçiminde; `~/.config/pypr/config.toml`
  pyprland tarafından okunmaz).
- `argos-translate` `wuwa-auto.sh` tarafından çağrılıyordu ama **hiçbir
  `.nix` dosyasında tanımlı değildi** → eklendi.
- `wuwa-gemma` Ollama modeli hiçbir yerde oluşturulmuyordu →
  `wuwa-gemma-init.service` eklendi (elle çalıştırılır, otomatik 8 GB indirme yok).
- `install.sh`: `mkpasswd -m sha-512` → `--method yescrypt` + `whois` notu;
  ikinci çalıştırmada oluşan `hooks/hooks` iç içe dizini (`rm -rf` ile giderildi);
  wallpaper varsayılanı `home.nix`'teki yolla eşitlendi; dosyalar artık
  `/etc/nixos/nixos/` altına kopyalanıyor (flake diziniyle uyumlu).
- 4 inline script (`wuwa-auto.sh`, `auto-translate.sh`, `waybar-temperature.sh`,
  `mpvpaper-watchdog`) `#!/usr/bin/env bash` → `#!${pkgs.bash}/bin/bash`.
- Firewall'dan 1714–1764 TCP/UDP aralığı (51 port) kaldırıldı.
- `/etc/vulkan/implicit_layer.d` hem `environment.etc` hem `environment.persistence`
  ile yönetiliyordu (bind-mount gölgeleme riski) → persistence kaldırıldı.
- `home.nix` fish alias'ları `/etc/nixos#nixos` diyordu, flake ise
  `/etc/nixos/nixos` altında → düzeltildi.
- CI: `nix-installer-action@main` → commit SHA'sı; `nix-instantiate --parse`,
  `statix`, `deadnix`, `shellcheck`, XML doğrulaması ve stale-dosya regresyon
  kontrolü eklendi.
- `CONTRIBUTING.md` flake yolu `./nixos#nixos` yapıldı.
- `KURULUM.md`: "50 GB" → "800 GB"; `@home/.snapshots` alt hacmi §6'ya doğru
  sırayla eklendi (`@home` mount edildikten sonra); mevcut sistemler için
  ön-koşul notu.

## 🧹 Removed — ikinci kaynaklar (drift kaynağı)

Bu dosyalar `home.nix` içindeki inline kopyalarla **drift** etmişti ve hiçbir
zaman deploy edilmiyordu. `home.nix` tek doğruluk kaynağı olarak bırakıldı:

```

.config/hypr/hyprland.conf        .config/hypr/hypridle.conf
.config/hypr/hyprlock.conf        .config/hypr/scripts/wuwa-auto.sh
.config/hypr/scripts/auto-translate.sh
waybar/style.css                  waybar/config.jsonc
gtk/gtk.css                       gtk/settings.ini
low_latency_layer.json            VkLayer_LS_frame_generation.json
etc/libvirt/hooks/qemu            nixos/low_latency_layer.json.in
conf.toml                         MangoHud.conf

```

> Not: `waybar/` ve `gtk/` **kökte**, `.config/` altında değildi. Daha önce
> yayımlanan bir düzeltme listesi bu yolları `.config/waybar/…` ve
> `.config/gtk-3.0/…` şeklinde yazıyordu; o komutlar `git rm` hatası verirdi.

## ⚠️ Known Issues (bilinçli olarak ertelendi)

- Navi 22 (RX 6000) `gnif/vendor-reset` destek listesinde değil; VM sonrası
  GPU reset sorunu donanıma bağlı. Hook'taki `remove` + `rtcwake` + `rescan`
  kurtarma yolu birçok kartta işe yarar, garanti değildir. Çözülmezse host
  reboot en güvenlisi. (README "Known Limitations" bkz.)
- Hyprland 0.55.0 (2026-05-09) nixpkgs'e (2026-09-28) göre ~4.5 ay geride;
  ecosystem uyumsuzluk riski nedeniyle yükseltilmedi.
  > **Düzeltildi (1.2.2):** yön tersti. nixpkgs `nixos-unstable` (2026-09-28)
  > **0.54.3** veriyor; Hyprland 0.55.0 nixpkgs'tan İLERİDE, geride değil.
  > Gerçek sorun farklıydı: overlay 0.55'e zorlarken `hyprlock` / `hypridle` /
  > `xdg-desktop-portal-hyprland` 0.54.3'e karşı derlenmişti. Overlay kaldırıldı,
  > tüm aile tek nixpkgs rev'inden geliyor.
- flake.lock'ta üç ayrı nixpkgs kopyası var (`nixpkgs_3` kök, `nixpkgs`
  cachyos-kernel, `nixpkgs_2` hyprland). Sadeleştirme flake mimarisini
  değiştirir.
- Swap LUKS dışında, açık bölümde. Şifreleme repartition gerektirir.
- `wuwa-auto.sh` sabit 2560×1440 ekran koordinatları ve 3 saniyelik OCR döngüsü
  kullanıyor; açık bırakılırsa oyun performansını ciddi şekilde düşürür.
- `scroll:down` binding'i, `layoutmsg set monocle` / `cyclenext` dwindle uyumu
  ve `hyprlock auth-msg` geçerliliği runtime'da doğrulanmadı.

---

# [1.1.2] - 2026-09-27

## 🐛 Fixed

- **`home.nix` xdg.configFile paths broke `install.sh` installs.** The two
  hypr scripts (`wuwa-auto.sh`, `auto-translate.sh`) were deployed via a
  path relative to the repo root (`../.config/hypr/scripts/...`). This
  only resolves correctly when `home.nix` is evaluated from inside a full
  repo checkout. `install.sh` copies `home.nix` alone into `/etc/nixos/`
  without the `.config/` directory, so on an installer-based setup the
  relative path pointed at a file that doesn't exist and `nixos-rebuild`
  would fail evaluation. Fixed by inlining both scripts' contents directly
  in `home.nix` (no external file dependency at all now).
- **`install.sh` didn't apply the user's GPU PCI address to the actual
  hook.** The installer asks for `GPU PCI` / `GPU Audio` addresses and
  patches `configuration.nix`'s `gpuPCI`/`gpuAudio` — but those two
  variables aren't read by anything; the real VFIO behavior comes from
  `GPU_PCI`/`GPU_AUDIO` hardcoded in `hooks/qemu`. On any machine whose GPU
  isn't at `0000:0b:00.0`/`.1`, the installer silently produced a broken
  VFIO setup despite asking for and appearing to accept the correct
  addresses. `install.sh` now also sed-patches the copied `hooks/qemu`.
- **`hooks/qemu` `prepare`: no failure detection or rollback.** If
  `bind_vfio` silently failed (errors were swallowed), the script still
  logged "GPU vfio-pci'ye bağlandı" and returned success — after already
  stopping greetd and unbinding the VT/EFI framebuffer. The VM could then
  fail to start with the host left headless and no automatic recovery.
  Added `device_bound_to_vfio()` verification; on failure the hook now
  rolls back (restores the host driver, VT console, EFI framebuffer,
  greetd) and exits non-zero so libvirt aborts the domain start instead of
  proceeding with a half-configured system.
- **`hooks/qemu` `release`: recovery check only verified the GPU, not
  audio.** After the `suspend_rescan_recovery` fallback, only `$GPU_PCI`
  was re-checked for a real driver. If the recovery fixed the GPU function
  but left the audio function driverless, the hook had no way to know and
  logged nothing. Now both functions are verified independently.

---

# [1.1.1] - 2026-09-27

## 🐛 Fixed

- **`install.sh` didn't copy `low_latency_layer.json.in`.** `configuration.nix`'s
  `low-latency-layer` derivation reads this file via a relative path
  (`./low_latency_layer.json.in`), which resolves against the directory
  `configuration.nix` itself lives in. `install.sh` copied
  `configuration.nix`/`home.nix`/`flake.nix`/`flake.lock`/`hooks/` into
  `/etc/nixos` but never this file, so on any install done through the
  installer, `nixos-rebuild switch` failed evaluation with a missing-path
  error the moment it tried to build the Vulkan layer. `install.sh` now also
  copies `low_latency_layer.json.in` alongside the other nixos/ files.
- **`home.persistence` (impermanence) was never wired into Home Manager.**
  `home.nix` sets `home.persistence."/nix/persist/home"`, but that option is
  defined by impermanence's *Home Manager* module, not its NixOS module.
  `flake.nix` only imported `impermanence.nixosModules.impermanence` at the
  system level — nothing passed the Home Manager module into
  `home-manager.users.localhost`, so the option didn't exist and
  `nixos-rebuild switch` failed evaluation with "option `home.persistence`
  does not exist".

  ⚠️ **Not (2026-10-03):** Bu entry'nin önerdiği "fix"
  (`home-manager.sharedModules = [ impermanence.homeManagerModules.impermanence ]`)
  **YANLIŞTIR.** O çıktı artık deprecated ve sadece `assertion = false`
  içeriyor → build'i kırar. Doğru yaklaşım:
  `impermanence.nixosModules.impermanence` modülü, HM modülünü otomatik olarak
  `home-manager.sharedModules`'a enjekte ediyor (bkz. `impermanence/nixos.nix`).
  `flake.nix`'teki yorum bu yüzden "elle import ETMEYİN" der.

---

# [1.1.0] - 2026-05-19

## ✨ Added

### 🎮 Gaming
- low_latency_layer implementation
- RADV_ANTILAG support
- lsfg-vk integration
- NVIDIA spoofing layer

### 🧰 Development
- install.sh automation script
- shell.nix development shell
- improved validation workflow

### 📚 Documentation
- rewritten README
- expanded KURULUM.md
- improved CONTRIBUTING.md

---

## 🔄 Changed

- improved markdown structure
- fixed formatting issues
- synchronized repo layout
- clarified VFIO workflow

---

# [1.0.0] - 2026-05-12

## 🎉 Initial Release

### Core Features
- Hyprland Wayland setup
- VFIO single-GPU passthrough
- CachyOS BORE kernel integration
- PipeWire low-latency audio
- GameMode + MangoHud + Gamescope
- Ollama ROCm support
- Snapper snapshots
- AppArmor security
- Waydroid support
- Looking Glass integration





---

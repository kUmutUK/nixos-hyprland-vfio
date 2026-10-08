> # ⛔ SÜPERSEDED — GÜNCEL KOD İÇİN KULLANMA
>
> Bu rapor `nixos-hyprland-vfio(1).zip` **düzeltmelerden ÖNCE**ki hâli için
> yazıldı. Bulgularının hepsi incelendi; uygulanan ve çekilen ayrımı
> `CHANGELOG.md` → `[1.3.4]` bölümünde kayıtlı. Özellikle:
>
> - Raporun `B-4 / HOST_USER` maddesi *"kod değiştirilmedi"* diyor — sonradan
>   **düzeltildi** (`vfioHook` gövdesine `export HOST_USER` eklendi).
> - Raporun `brightnessctl` maddesi *"ekranı parlatıyor"* diyor — sonradan
>   **çekildi** (yön başlangıç değerine bağlı, hedef donanımda no-op).
>
> Ayrıca bu raporun bulduğu `mogrify` eksikliği hiç geçmemişti; o bulgu
> ikinci turda çıkarıldı ve düzeltildi.
>
> Güncel kayıt tek yerde: `CHANGELOG.md` → `[1.3.4]`.

# `nixos-hyprland-vfio(1).zip` — Analiz Raporu (v2, düzeltilmiş)

**Tarih:** 2026-10-08 · **Kapsam:** 23 dosya / ~18.800 satır
**Yöntem:** Tam statik okuma + çalıştırma testleri (extractor, xargs gate semantiği, GitHub Actions shell varsayılanı, PNG kuyruk analizi)

> **v2 notu:** İlk turda öne sürülen 5 bulgudan **2'si çekildi**, 2'si düzeltildi,
> 1'i yeniden sınıflandırıldı. Ayrıca ilk turdaki bir hatam tespit edildi
> (aşağıda "Düzeltilen hatam" bölümü). Bu rapor **v2**'dir; v1'i kullanma.

---

## 0. Kısa hüküm

**Zararlı yazılım yok. Kötü niyetli hiçbir bulgu yok.** Zararsızlığı tahmin
değil, test ettim:

| Kontrol | Sonuç |
|---|---|
| Uzak kod çekme / `curl \| bash` / `eval` | **Yok** — tek `curl` çağrısı `http://localhost:11434` (yerel Ollama) |
| Gömülü SSH anahtarı / API token / webhook | **Yok** — bakımcının açık anahtarı `configuration.nix:394-410`'da **kaldırılmış** |
| PNG'e eklenmiş veri (steganografi/kuyruk) | **Yok** — her iki PNG'de de `IEND` sonrası **0 bayt** |
| Base64/obfuscation payload | **Yok** |
| `hashedPassword` içeriği | **Yok** — `*` placeholder, `.gitignore`'da da yasaklı |

---

## 1. ✅ AYAKTA KALAN BULGULAR

### B-1 · CI kapısı, hiçbir şey taramadan yeşil kalıyordu — **DÜZELTİLDİ**
**`.github/workflows/check.yml:46`** · **Önem: Yüksek**

```bash
python3 scripts/extract-embedded-scripts.py /tmp/emb | xargs -0 -n1 -- shellcheck -S warning
```

İki ayrı zaafiyet üst üste biniyordu:

1. **`xargs` `-r` / `--no-run-if-empty` bayrağı yoktu.** Boş girdide `xargs`
   komutu **sıfır argümanla bir kez** çalıştırır. Shellcheck dosya adı
   almayınca stdin'i okur, pipe zaten boşaldığı için temiz çıkar, `exit 0` döner.
2. **Bu step'te `shell:` anahtarı tanımlı değil** → GitHub Actions varsayılanı
   `bash -e {0}` → **`pipefail` YOK**. (`shell: bash` yazılsaydı
   `bash -eo pipefail` olurdu.) Yani extractor'ın **çökmesi** de yutuluyordu;
   `set -e` sol tarafı korumuyor.

**Deneyle doğrulandı** (sandbox, CI'daki kabuk semantiği taklit edilerek):

```
--- normal: 7 betik ---                    → 7 kez shellcheck, exit 0   ✓
--- 0 betik (stdout boş) ---               → arg count=0, exit 0        ✗ SİLİNTİ GEÇİŞ
--- extractor exit 3, set -e altında ---   → exit 0                     ✗ HATA YUTULDU
```

> ⚠️ **Düzeltilen hatam:** İlk turda "GitHub Actions `pipefail` kullanır, çöken
> extractor yakalanır" yönünde bir muafiyet varsaymıştım. Bu workflow için
> **yanlıştı**: `shell:` anahtarı olmadığı için `bash -e {0}` çalışıyor.
> `set -e` altında `{ python3 -c 'exit 3'; } | xargs ...` hâlâ `exit 0` veriyor.
> Yani **çökme senaryosu da sessizce geçiyordu** — muafiyet yoktu.
> (0-senaryo bulgusu zaten pipefail'dan bağımsızdı ve zaten ayaktaydı.)

**Sonuç:** `home.nix` içindeki `hypr/scripts/...` desenleri bir refactor'da
kayarsa extractor 0 betik bulup mutlu mesut çıkıyor, `echo "OK"` basıyor, kapı
yeşil kalıyor. Bu tam olarak `[1.3.0]`'ta bu adımı ekleme gerekçesi olarak
yazılan hata sınıfı — kapı, bulunmak için kurulduğu hata sınıfını üretiyordu.

**Uygulanan düzeltme:** `shell: bash` (pipefail açık) + boş çıktı `::error::`
ile reddediliyor + sayaç 7'nin altına düşerse uyarı + `xargs -r` + kaç betiğin
tarandığının yazdırılması.

**Doğrulama:** normal yol 7 betik → yeşil; 0 betik → `exit 1` (kırılıyor, düzeldi).

---

### B-2 · `hyprlandMonitorLine` yorumu kendi değerini yanlış tanımlıyordu — **DÜZELTİLDİ**
**`nixos/home.nix:7-11`** · **Önem: Düşük**

```nix
# ... "buradaki değer yalnızca manuel klonlayanları korur"
hyprlandMonitorLine = "monitor = ,preferred,auto,1";   # ← boş monitör adı = sorunun kendisi
```

Yorum *"korur"* diyordu, duran değer ise sorunun kendisiydi. Yorum doğru teşhisi
yapıp yanlış sonuca bağlanıyordu: elle klonlayan tam olarak o bozuk davranışı
alıyordu.

**Düzeltme:** Değer `KURULUM.md` §7b'in de zaten önerdiği gerçek örneğe çevrildi
(`monitor = DP-1,preferred,auto,1`), yorum yeniden yazıldı, `KURULUM.md` §7b
tablosunun varsayılan sütunu buna göre güncellendi.

---

## 2. ⚠️ YENİDEN SINIFLANDIRILAN

### B-3 · hypridle parlaklık adımı — belgelenmemiş tuhaflık, **davranış değiştirilmedi**
**`nixos/home.nix:1590-1592`**

`brightnessctl -s set 70%` bir "karartma" **değil**, mutlak %70'e sabitlemedir.
Yönü tamamen başlangıç değerine bağlıdır: %40'ta çalışıyorsa **parlatır**,
%100'de çalışıyorsa kısar. "İdeal %70" gibi bir varsayım yok.

Ayrıca harici monitörlü masaüstülerde `/sys/class/backlight/` genelde **boştur**;
brightnessctl "No device found" deyip hiçbir şey yapmaz — yani bu satır hedef
donanımda büyük olasılıkla **sessiz bir no-op**tur. İç paneli olan dizüstülerde
ise gerçekten parlaklığı değiştirir.

Zamanlama bağlamı: 150 sn'de parlaklık, 300 sn'de `dpms off` → 150–300 sn arası
ekran **açık** kalıyor.

> **Çekilen iddia:** İlk turda "150. saniyede ekranı kısacağı yerde parlatıyor"
> denmişti. Bu **koşulsuz** ifade yanlıştı — yön başlangıç değerine bağlı ve
> hedef donanımda büyük olasılıkla hiç çalışmıyor. Doğru ifade: *"mutlak atama,
> yönü baseline'a bağlı, hedef donanımda muhtemelen no-op."*

**Yapılan:** Yalnızca yorum eklendi — davranış **değiştirilmedi** (tasarımın
sahibinin tercihi). Doğru alternatifler (`--set 10%-` ya da listener'ı
kaldırmak) yorumda belirtildi.

---

### B-4 · `HOST_USER` — hata değil, belgelenmiş ve ertelenmiş bir sınırlama
**`nixos/hooks/qemu:145`**

```bash
loginctl terminate-user "${HOST_USER:-localhost}"
```

`HOST_USER`'ı **kimse export etmiyor** (doğrulandı: config'in hiçbir yerinde
geçmiyor). **Ancak** `configuration.nix` kullanıcı adını zaten `localhost`'a
sabitliyor (`users.users.localhost`), `home.nix` de `home.username = "localhost"`
diyor ve `install.sh` kullanıcı adı **sormuyor**. Varsayılan akışta fallback
doğru kullanıcıyı sonlandırıyor — kurulum çalışıyor.

Sorun **yalnızca** hesap adını config'in 3+ noktasından değiştirirsen ortaya
çıkıyor: oturumlar kapanmıyor → GPU kilitli → `stop_hyprland` zaman aşımı →
rollback → VM açılmıyor.

> **Çekilen ifade:** "fix uygulanmamış / ihmal edilmiş" değil. `[1.3.3]` teşhisi
> koymuş, yanlış talimatı kaldırmış, doğru çözümü yazmış — sadece uygulamamış,
> çünkü varsayılan akışta çalışan bir default var. Bu bir sınırlamadır.

**Yapılan:** Kod **değiştirilmedi**; CHANGELOG'da doğru sınıflandırmayla kayıt altına alındı.

---

## 3. ❌ ÇEKİLEN İDDİA

### "docs/archive/ kullanıcıyı yanıltıyor" — **GERİ ALINDI**

İlk turda "arşivdeki raporlar çoktan çözülmüş 2 hatayı kovalatıyor" dedim.
**Bu haksızdı.** `docs/archive/README.md` zaten `# Arşiv — SÜPERSEDED analizler`
başlığını taşıyor ve *"Bu klasördeki belgeler eski sürümlere karşı yazılmıştır"*
diyerek klasörün **tamamını** kapsıyor. Ayrıca ZIP3 raporunun iki P1 maddesini
tek tek "Düzeltildi" / "Fiilen gerçekleşmiyor" diye işaretlemiş, kalanı için
`CHANGELOG [1.3.0]`'a yönlendirmiş. Arşiv **doğru yapılmış.**

**Kalan tek gerçek sorun (daha zayıf):** README yalnızca 2 `-SUPERSEDED`
dosyayı açıklıyordu; `NIXOS-HYPRLAND-VFIO-ANALIZ.md` ve `DEGISIKLIKLER.md`
hiç anılmıyordu. Bu "rapor yanıltıyor" değil, **"raporun yeri belirsiz"** —
kullanıcı doğrudan dosyayı açtığında karşılayacağı ilk şey kendi güçlü hükmü.

**Düzeltilen (kısmi):** Dört raporun tamamı README'ye tek tek listelendi, her
biri için "güncel kodda hangi maddesi geçersiz" tablosu eklendi, ve
`NIXOS-HYPRLAND-VFIO-ANALIZ.md`'in en üstüne ⛔ SÜPERSEDED afişi kondu
(§0'ın *"sistem şu an hâliyle derlenmiyor"* hükmü artık geçersiz: hem
`installPhase` hem `python3` maddeleri düzeltildi). Yeni arşiv dosyası
eklenirse ne yapılacağı da README'ye yazıldı. `[1.3.2]`'deki *"4 dosya"* sayımı
**5** olarak düzeltildi.

---

## 4. Temiz çıkan noktalar (kontrol ettim, sorun yok)

- **`--accept-flake-config`**: Şüpheli buldum. CI kaldırmış, README/KURULUM veriyor.
  **Bu bir çelişki değil** — CI'ın gerekçesi "lock'u kirletmesi" (CI hijyeni);
  kullanıcı için bayrak **gerekli**: `flake.nix:10-19`'daki cachix
  substituters'ları ancak o bayrakla uygulanır. Doğru tasarım.
- **`stateVersion = "26.05"`**: 2026-10 itibarıyla en güncel kararlı sürüm 26.05
  (bir sonraki 26.11). Doğru.
- **`flake.lock`**: Kanonik. `impermanence.inputs` altındaki `home-manager` ve
  `nixpkgs` ikisi de **follows formunda** (`["home-manager"]` / `["nixpkgs"]`) —
  CI'ın tarif ettiği bozukluk zaten düzeltilmiş. "lock değişmesin" kapısı yerinde.
- **`home.nix` parantez dengesi**: `{`/`}` **317/317 dengeli**. `[`/`]` 114/113
  — ama bu **orijinalde de aynı** ve Nix string'leri içindeki `]`'lerden
  (`sed 's/[^a-zA-Z0-9.,!? ]//g'` gibi). Zararsız, benim eklediklerimden değil.
- **Ollama/ROCm zinciri**: `cfgpkg` ile `services.ollama.package` ikisi de
  `pkgs.ollama-rocm`; `rocmOverrideGfx = "10.3.0"` RX 6700 XT (gfx1030) ile
  uyumlu. Tutarlı.
- **VM XML**: `<video><model type="none"/>` passthrough için doğru;
  `<kvm><hidden state="on"/>` VM'yi CPU markasından gizliyor. 16 GiB / 6 vCPU
  Ryzen 5 5600 ile uyumlu.
- **`install.sh` PCI doğrulaması** (`:115-131`): gerçek regex + 3 denemelik döngü.
  `hooks/qemu`'ya geçersiz değer yazılamıyor.
- **Gömülü bash betikleri**: extractor 7 betik üretiyor. `tr -d 'f'` felaketi
  (Nix `\f` kaçışı) düzeltilmiş ve yorumla kayıt altına alınmış.

---

## 5. Uygulanan değişiklik özeti

| Dosya | Değişiklik |
|---|---|
| `.github/workflows/check.yml` | Gate'e `shell: bash`, 0-betik `::error::` kapısı, sayaç uyarısı, `xargs -r` (+38 satır) |
| `nixos/home.nix` | `hyprlandMonitorLine` gerçek örneğe çevrildi; parlaklık adımına doğru açıklama yorumu (+31 satır, kod dışı 1 satır) |
| `KURULUM.md` | §7b tablosunun varsayılan sütunu güncellendi (2 satır) |
| `docs/archive/README.md` | 4 raporun tamamı listelendi + geçersizlik tabloları + yeni dosya kuralı (+29 satır) |
| `docs/archive/NIXOS-HYPRLAND-VFIO-ANALIZ.md` | ⛔ SÜPERSEDED afişi (+16 satır) |
| `CHANGELOG.md` | `[1.3.4]` bölümü; `[1.3.2]`'deki dosya sayımı 4→5 (+109 satır) |

**Değişmeyen 17 dosya** — `install.sh`, `nixos/hooks/qemu`, `configuration.nix`,
`flake.nix`, `flake.lock`, `hardware-configuration.nix`, `win10.xml`, extractor,
README, LICENSE, CONTRIBUTING, `.gitignore`, 2 PNG, 1 arşiv raporu.

### Doğrulama sonuçları
```
bash -n install.sh          → OK
bash -n nixos/hooks/qemu    → OK
python py_compile extractor → OK
xml.dom.minidom win10.xml   → OK (well-formed)
extractor → 7 betik         → OK (orijinalle bit-bit aynı)
yeni gate, 7 betik          → yeşil
yeni gate, 0 betik          → exit 1 (kırılıyor ✓)
yeni gate, extractor exit 3 → yakalanıyor ✓
```

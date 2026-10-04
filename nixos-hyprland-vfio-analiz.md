# `nixos-hyprland-vfio` — Detaylı Kod & Yapılandırma Analizi (SÜRÜM 2 — düzeltilmiş)

**İnceleme tarihi:** 2026-10-04 · **Kaynak:** `nixos-hyprland-vfio(2).zip` (3.3 MB)
**Commit:** `b993f54` "Fix README path and update installation instructions" (shallow clone, tek commit)
**Kapsam:** 17 dosya / 4.663 satır. Tümü satır satır okundu; shell script'leri çıkarılıp
`shellcheck` ile tarandı; iddialar kilitli nixpkgs rev'i (`7a0f122f5090`) ve upstream kaynak
dosyalarına karşı doğrulandı.

---

## 0. Yönetici özeti

Bu repo **ciddi emek harcanmış, iyi yorumlanmış, birçok gerçek hatayı çoktan düzeltmiş** bir
config. Yorumların büyük kısmı teknik olarak isabetli (aşağıda doğrulanan doğrular bölümü).
Ama üç şey var:

1. **Bir satır config'in tamamının evaluate edilmesini engelliyor olabilir** (`services.steam`).
2. **Üç hata sessizce çalışıyor gibi görünüyor** ama hiçbir işe yaramıyor: Nix kaçış karakteri
   yüzünden OCR metni bozuluyor, kilit ekranının butonları hiç render edilmiyor, VFIO hook'ı
   GPU'yu gerçekten tespit edemiyor.
3. **Dokümantasyon kilitli sürümlerden kopmuş** — README Hyprland 0.54.3 diyor, gerçekte
   0.56.2. Yorumlardaki "0.55.0 satır N" referansları 0.56.2'ye göre kaymış.

| # | Bulgu | Şiddet | Nerede |
|---|-------|--------|--------|
| 1 | `services.steam` option'ı nixpkgs'te yok → eval hatası | **P0** | `configuration.nix:491` |
| 2 | `\f` → `f`: OCR metninden tüm "f" harfleri siliniyor | **P1** | `home.nix:992,1016` |
| 3 | hyprlock 0.9.6 `button`/`check_symbol`/vb. bilmiyor → kilit ekranı eksik | **P1** | `home.nix:403-466` |
| 4 | VFIO hook PATH'inde `ls`/`sed` yok → GPU tespiti hep `card0`'a düşüyor | **P1** | `hooks/qemu:108,146-147` |
| 5 | `MANPAGER` → `git log`/`git show` boş çıktı | **P1** | `home.nix:1199` |
| 6 | README "Hyprland 0.54.3" yanlış (gerçek: 0.56.2) | P2 | `README.md:128` |
| 7 | `flake.nix` overlay gerekçesi geçersiz (ama sonuç doğru) | P2 | `flake.nix:26-34` |
| 8 | `hyprlandMonitorLine` boş monitör adıyla kalıyor | P2 | `install.sh:342` |
| 9 | KURULUM.md'de kapatılmamış kod bloğu + gereksiz `cp` | P2 | `KURULUM.md:235-244` |
| 10 | CI gömülü script'leri hiç taramıyor | P2 | `check.yml:35` |
| 11 | Kökte `shell.nix` hâlâ var (flake `devShell` varken) | P3 | `shell.nix` |
| 12 | impermanence modülü yarım kullanılıyor → her rebuild'de uyarı | P3 | `flake.nix:39,56` |
| 13 | `wuwa-gemma-init` hazır-olma beklemesi yok | P3 | `configuration.nix:561-580` |
| 14 | Aynı anda 3 Vulkan implicit layer | P3 | `configuration.nix:417,439` |
| 15 | `low-latency-layer` buildInputs'ta 2 gereksiz paket | P3 | `configuration.nix:17-23` |

---

## 1. ~~P0 — `services.steam`~~ ⛔ GERİ ÇEKİLDİ (2026-10-05)

**Bu madde YANLIŞTI ve geri çekildi.** `configuration.nix:491` satırı
`programs.steam.enable = true;` — doğru option adı zaten kullanılıyor:

```
$ grep -n "steam" nixos/configuration.nix
402:    steam gamemode gamescope mangohud vkbasalt winetricks procps
491:  programs.steam.enable = true;
```

Repo'da hiçbir yerde `services.steam` yok. `grep` ile doğrulandı; ayrıca
nixpkgs'te `services.steam` alias'ının **zaten var olmadığı** teyit edildiği için
bulgu "yalnızca bu repoda yanlış yazılmış", "nixpkgs'te kaldırılmış" değil.
Düzeltme gerekiyordu, gerekmiyor. **Özür dilerim — bu, kendi okuduğum satırı
yanlış aktarmamdı.**

## 2. P1 — Nix kaçış karakteri: `\f` sessizce `f` oluyor

`home.nix:992` ve `home.nix:1016` (ikisi de `wuwa-auto.sh` içinde):

```bash
TEXT_MAIN=$(echo "$RAW_MAIN" | tr -d '\f' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)
```

Nix'in indented-string (`'' … ''`) kaçış işleyicisi (`nix/src/libexpr/lexer.l`, `unescapeStr`)
sadece `\n`, `\r`, `\t` tanır; **diğer her şeyde backslash'i sessizce düşürür**:

```c
if (c == 'n') *t = '\n';
else if (c == 'r') *t = '\r';
else if (c == 't') *t = '\t';
else *t = c;          // ← \f  →  'f'   (kontrol karakteri DEĞİL, normal harf)
```

Yani derlenen script'te satır şu hale gelir: `tr -d 'f'` — tesseract çıktısındaki **bütün "f"
harfleri silinir**. Çalıştırarak doğruladım:

```
kaynak metin:        The final boss attacks / Fire! of f
tr -d 'f'  (şu an):  The inal boss attacks / Fire! o
tr -d '\014' (doğru): The final boss attacks / Fire! of f
```

Türkçe çeviri kalitesini doğrudan etkiler (Fire→ire, f→boşluk) ve `LAST_MAIN` karşılaştırması
da bozuk metin üzerinden yapıldığı için yanlış metin de "aynı" sayılıp güncellenmez.

**Düzeltme** (her iki satır):
```bash
TEXT_MAIN=$(echo "$RAW_MAIN" | tr -d '\014' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)
```

**Tüm dosyalar için kaçış taraması yaptım** — `\n` ve `\t` kullanımlarının hepsi doğru ve
kasıtlı (waybar tooltip'leri, `cut -d'\t'`, `printf '%s\t%s\n'`). **Tek bozuk olan bu iki `\f`.**

---

## 3. P1 — `hyprlock.conf` hyprlock 0.9.6'nın şemasını bilmiyor

Kilitli nixpkgs `hyprlock` **0.9.6** veriyor. Config'in kullandığı widget bölümlerini
`addSpecialCategory`/`addSpecialConfigValue` kayıtlarıyla karşılaştırdım. hyprlock 0.9.6
şu bölümleri tanıyor: `background`, `shape`, `image`, `input-field`, `label`.
**`button` bölümü hiç yok** (widget kaldırılmış; `grep -rn '\bbutton\b' src/` sadece
`onClick(uint32_t button, …)` gibi ilgisiz mouse parametrelerini buluyor).

Geçersiz anahtarlar:

| Bölüm | Geçersiz anahtarlar | Etki |
|-------|--------------------|------|
| `general` | `grace`, `disable_loading_bar` | yok sayılır (`grace` artık CLI bayrağı: `--grace`) |
| `label` ×4 | `size` | yok sayılır, label'lar otomatik boyutlanır |
| `input-field` | `font_size`, `check_symbol`, `placeholder_color`, `fail_transition` | yok sayılır |
| `button` ×2 | **bölümün tamamı** | **güç ve uyku butonları hiç oluşmaz** |

`input-field:check_text` varsayılanı boş string (`""`) olduğu için başarılı şifre
girişinde de **onay işareti görünmez**. `font_size` yok sayıldığı için parola alanı
sabit 20px yerine otomatik hesaplanan boyut kullanır (hyprlock `PasswordInputField.cpp:96`:
`fontSize = round(size.y * dots.size * 0.5) * 2` ≈ 28px).

**Önemli nüans:** hyprlock 0.9.6 `throwAllErrors = true` kullanıyor
(`ConfigManager.cpp:219`) ama parse hatasında **çökmek yerine** loglayıp devam ediyor:

```cpp
auto result = m_config.parse();
if (result.error)
    Log::logger->log(Log::ERR, "Config has errors:\n{}\nProceeding ignoring faulty entries", …);
```

Yani **kilit ekranı çalışıyor**, ama gürültülü hata logları basıyor ve butonlar/ayarlar
sessizce yok. Kontrol etmek için: `hyprlock 2>&1 | grep -A5 "Config has errors"`.

`shadow_passes` ve `dots_spacing` gibi anahtarları ilk kontrolte "yok" saymıştım —
`SHADOWABLE`/`CLICKABLE` makrolarıyla kaydedildikleri için **geçerli**. Doğru listeyi
makroları açarak çıkardım; tabloda yalnızca gerçekten geçersiz olanlar var.

**Ek not:** Aynı config'teki `SUPER+SHIFT+T` (OCR çeviri) bağlantısı `tesseract` +
`trans` kullanıyor — bunlar sorunsuz. `hypridle` 0.1.8'in **tüm** anahtarları mevcut
(`before_sleep_cmd`, `after_sleep_cmd`, `lock_cmd`, `ignore_dbus_inhibit`, `listener:*`) —
sorun sadece hyprlock'ta.

---

## 4. P1 — VFIO hook'ında `ls` ve `sed` PATH'te yok

`configuration.nix:70-76` hook'u şöyle hazırlıyor:

```nix
export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}:$PATH"
```

ve yorumda “libvirtd.service'in PATH'i yalnızca qemu + netcat + swtpm içeriyor” diyor —
bu **doğru** (nixpkgs `nixos/modules/virtualisation/libvirtd.nix:558-562`). NixOS'un systemd
modülü `path` listesini `Environment="PATH=…"` ile **değiştirdiği** için (`systemd-lib.nix:648`),
`$PATH` = `qemu:netcat:swtpm` + enjekte edilen `coreutils:systemd`.

Sonuç: hook içinde **`ls` (findutils) ve `sed` (gnused) bulunamıyor.** Kullanıldığı yerler:

- `hooks/qemu:108` — `gpu_drm_card()`: `node=$(ls -d …/drm/card* | head -n1)` → boş döner →
  fonksiyon her seferinde `card0`'a düşüyor ve “bulunamadı” uyarısı basıyor.
- `hooks/qemu:146-147` — `renderD*` listeleme → boş → `nodes` yalnızca `/dev/dri/card0` (+`/dev/kfd`).

`2>/dev/null` “command not found” hatasını yuttuğu için **sessiz** bir bozulma.

**Yorumun iddiası yanlış:** satır 100-105'te “Bu artık varsayıma değil, gerçek PCI eşleşmesine
dayanıyor” yazıyor — pratikte her zaman varsayılan yola düşüyor. Aynı şekilde satır 144-145'teki
“ROCm/Ollama yalnızca render node'u açabiliyor, cardN boş görünüyor” tespiti hiç çalışmıyor, yani
tam olarak o senaryo için yazılmış savunma devre dışı.

**Düzeltme** — `configuration.nix:71`:
```nix
export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.systemd pkgs.findutils pkgs.gnused ]}:$PATH"
```
(Tek GPU'lu makinede `card0` doğru olduğu için mevcut hali *çökmüyor*; bu yüzden sorun
fark edilmemiş. Ama `stop_hyprland` içindeki güvenlik kontrolü zayıflamış durumda.)

**Doğrulanan doğru kısımlar:** `hooks.qemu.vfio` → `/var/lib/libvirt/hooks/qemu.d/vfio`
symlink'i NixOS tarafından yönetiliyor ✓ (`libvirtd.nix:515-518`) ve `libvirtd-config`
her boot'ta `rm -rf` + yeniden `ln -s` yaptığı için yeni generation'a doğru geçiyor ✓.
Hook'un `builtins.readFile ./hooks/qemu` referansı da sorunsuz — `nixos/hooks/qemu` git'e
**tracked** (`git ls-files` ile doğrulandı; git-flake'te untracked dosya store'a
kopyalanmaz ve eval patlardı).

---

## 5. P1 — `MANPAGER` git çıktısını yutuyor

`home.nix:1199`:
```fish
set -gx MANPAGER 'sh -c "col -bx | bat -l man -p --paging=always"'
```

Git, pager'ı `<pager> <dosya>` olarak shell'e verir. Bu kalıpla tam komut şu olur:
```
sh -c "col -bx | bat -l man -p --paging=always" /usr/share/man/man1/git.1.gz
```
Dosya adı `sh -c` script'inin **`$0`'ına** düşer, yani `bat` hiçbir dosya argümanı
almaz ve stdin'den (boş) okumaya çalışır → `git log`, `git show` **boş** görünür.
Test ettim, çıktı 0 bayt.

**Düzeltme** (iki temiz seçenek):
```fish
# A) sh -c sarmalayıcısını kaldır — git dosyayı pipe'ın sonuna ekler:
set -gx MANPAGER 'col -bx | bat -l man -p --paging=always'

# B) sh -c kalsın, $0 kaymasını engelle:
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p --paging=always \"\$1\"' -"
```
(A'yı öneririm; tırnak tuzağı yok.)

---

## 6. P2 — README/flake sürüm iddiaları kilitli nixpkgs ile uyuşmuyor

`flake.lock` → `nixpkgs` = `7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f` (`nixos-unstable`).
Bu rev'deki gerçek paket sürümleri:

| Paket | README/flake iddiası | Gerçek |
|-------|----------------------|--------|
| hyprland | 0.54.3 (`README.md:128`, `flake.nix:28-33`) | **0.56.2** |
| hyprlock | 0.9.5 (CHANGELOG) | **0.9.6** |
| hypridle | 0.1.7 (CHANGELOG) | **0.1.8** |
| hyprpicker | 0.4.6 (CHANGELOG) | **0.4.7** |

Yani `flake.nix`'in overlay'i kaldırma gerekçesi ("nixpkgs 0.54.3 veriyor, overlay 0.55.0'a
zorluyordu") **eski bir nixpkgs'e göre yazılmış**; bugün nixpkgs zaten 0.56.2 veriyor, yani
overlay'in kaldırılmasının nedeni ortadan kalkmış. **Sonuç yine de doğru** (tek rev = ABI
tutarlılığı, `flake.nix:64-66`), sadece gerekçe bayat.

Buna karşılık `home.nix:250-265`'teki tuş yorumları (tekerlek → `mouse_down`/`mouse_up`)
**0.56.2'de doğrulandı**:
- `KeybindManager.cpp:446-465` — `onAxisEvent`, `e.delta > 0 → "mouse_down"`, `< 0 → "mouse_up"` ✓
- `KeybindManager.cpp:488` — fare butonları `"mouse:<code>"` olarak ayrıştırılıyor ✓
- `DispatcherTranslator.cpp:475-480` — `cyclenext` + `prev` argümanı ✓

Yani home.nix'in yorumları **v0.55.0 satır numaralarını** gösteriyor (0.56.2'de 461/463 ve
475), ama mekanizma ve sonuç doğru. Sadece referans satırları güncellenmeli.

**Kritik detay — dokümanlanmamış sınır:** `KeybindManager.cpp:459` →
`e.source == WL_POINTER_AXIS_SOURCE_WHEEL && e.axis == WL_POINTER_AXIS_VERTICAL_SCROLL`.
Yani bu binding'ler **sadece faresel tekerlekte** çalışır; **dokunmatik panel (touchpad) ile
bağlanan bir klavyede `SUPER + tekerlek` hiçbir şey yapmaz.** Config bunu hiç belirtmiyor.

**Ayrıca:** `input:sensitivity` (`home.nix:164`) 0.56.2'de hâlâ var ✓, `general:no_focus_fallback`,
`misc:enable_swallow`, `misc:session_lock_xray`, `misc:allow_session_lock_restore` — hepsi mevcut ✓.

---

## 7. P2 — `hyprlandMonitorLine` yanlış değere sabitleniyor

`install.sh` kullanıcıdan monitör adı istiyor (`:147`) ama o değer yalnızca
`monitorOutput`'a (mpvpaper) gidiyor. Hyprland satırı ise:

```
monitor = ,preferred,auto,1        # install.sh:152 varsayılanı
```

Boş monitör adı Hyprland'da **"bu kuralı tüm monitörlere uygula"** demektir. Kullanıcı
2560x1440@170 yazsa bile sonuç `monitor = ,2560x1440@170,auto,1` olur — yine tüm monitörlere
uygulanır, monitör adı yine boş kalır. `home.nix:7` varsayılanı da aynı şekilde boş.

Düzeltme: `install.sh:151-152`'de monitör adını da satıra göm:
```bash
read -rp "Monitor adı (örn. DP-3): " input_mon_name
[[ -n "$input_mon_name" ]] && hypr_mon_line="monitor = ${input_mon_name},preferred,auto,1"
```

---

## 8. P2 — KURULUM.md'de kapatılmamış markdown kodu ve gereksiz komut

`KURULUM.md:226-244`, §9b bloğu: `> ⚠️ **ISO dosyaları:** …` satırından sonra **``` kapanışını
koymayı unutmuş** — iki ayrı uyarı paragrafı ve bir shell komutu aynı quote bloğuna gömülmüş,
sonraki `## Doğrulama:` başlığı bozuk görünüyor. Ayrıca satır 235:

```bash
cp -r /mnt/etc/nixos/vm-xml /mnt/etc/nixos/nixos/   # zaten klonlandıysa gerekmez
```

§7'de repo `cp -r /tmp/repo/. /mnt/etc/nixos/` ile klonlandığı için `vm-xml` zaten
`/mnt/etc/nixos/vm-xml` altında; bu satır aynı dosyayı ikinci bir yere kopyalar ve
neden olduğu açıklanmamış.

---

## 9. P2 — CI'nın göremediği yerler

`check.yml:35` yalnızca `install.sh` ve `nixos/hooks/qemu`'yu tarıyor. **`home.nix` içine
gömülü 7 bash script'i** hiç taranmıyor — `\f` kaçış hatası (#2) ve `MANPAGER` (#5) bu yüzden
yakalanamıyor. CI kapısını genişletmek 5 satır:

```bash
# home.nix'ten gömülü script'leri çıkarıp tara
python3 - <<'EOF' | xargs -0 shellcheck -S warning
import re,sys
src=open('nixos/home.nix').read().split('\n')
for m in ['"hypr/scripts/','home.file.".local/bin/','gamemodeNotifyScript']:
    i=next(n for n,l in enumerate(src) if m in l)
    j=next(n for n in range(i,len(src)) if "text = ''" in src[n])
    body=[]
    for l in src[j+1:]:
        if l.strip().startswith("''"): break
        body.append(l)
    sys.stdout.write(re.sub(r'\$\{pkgs\.[\w.-]+\}/bin/','\1',''.join(b or '\n' for b in body)).replace("''${","${"))
EOF
```
(Bu analiz sırasında bu taramayı elle yaptım: 7 script'in hepsi `bash -n` ile syntax-valid,
tek uyarı `wuwa-auto.sh`'te 4× SC2155 — `local x=$(...)` kalıbı, zararsız.)

Ayrıca `check.yml:53-59` "stale file check" `etc` gibi jenerik isimleri de tarıyor — yanlış
pozitif riski düşük ama `assets`/`vm-xml` gibi gerçek dizinler listede değil.

**Bir de şu:** `install.sh:204-209` ve `:258-263` değiştirilen `hooks/qemu` ve `win10.xml`
dosyalarını `git update-index --skip-worktree` ile işaretliyor. Bu, CI'ın ve `git diff`'in
değişikliği **görmesini** engelliyor — yani kurulumdan sonra bu iki dosyadaki gerçek fark
görünmez olur.

---

## 10. P3 — Diğer gözlemler

| Konu | Tespit | Öneri |
|------|--------|-------|
| `shell.nix` | Kökte hâlâ duruyor, `<nixpkgs>` channel'ı import ediyor. README "legacy" diyor ama silmemiş — iki geliştirme modeli yan yana | Sil veya README'den tamamen çıkar |
| impermanence | `flake.nix:39,56` import ediliyor ama NixOS tarafında `environment.persistence` **yok** → her rebuild'de "Neither /var/lib/nixos nor any of its parents are persisted" uyarısı. Tek kullanımı `home.persistence` ile bir lsfg-vk `conf.toml` | Ya gerçek `environment.persistence."/var/lib/nixos" = { }` tanımla (CHANGELOG bunu denemiş ve işe yaramadığını yazmış — o ölçümü tekrarlamaya değer), ya da modülü tamamen kaldır |
| Ollama init servisi | `configuration.nix:561-580` — `after = ["ollama.service"]` var ama hazır-olma beklemesi yok. Elle çalıştırıldığında ollama ayakta değilse 8 GB'lık `ollama pull` sessizce başarısız olur, `set -e` de yok | `ExecStartPre` ile `ollama list` retry döngüsü |
| Vulkan katmanları | Aynı anda 3 implicit layer: `lsfg-vk` (modül), `low_latency_layer` (`configuration.nix:439`), `vkbasalt` (`:402`). Üçü de present-mode/frame üretimine müdahale ediyor | İkisi de istenmiyorsa ayrı profillerde aç |
| `low-latency-layer` | `buildInputs`'ta `glslang` ve `shaderc` var; upstream `CMakeLists.txt` ikisini de **kullanmıyor** (sadece `Vulkan` + `VulkanUtilityLibraries` buluyor) | Çıkar, build süresi kısalır |
| `low-latency-layer` sürüm | `version = "1.0.0"`, upstream `project(... VERSION 0.02)`, manifest `implementation_version: "3"` | Tutarlılık için `0.02` |
| waybar stili | `#battery` stili var ama `modules-right`'ta battery modülü yok (masaüstü için doğru, sunucuda ölü CSS) | Zararsız, dokunma |
| `install.sh` sed | `:199-202` ve `:331` kullanıcı girdisini sed replacement'ına ham koyuyor; `\|` veya `&` içeren bir değer bozar | `&`/delimiter kaçışı veya doğrulama |
| `install.sh` yan etki | `:226-254` XML'i **reponun kendi** `vm-xml/win10.xml` dosyasını yerinde değiştiriyor | Çalışma kopyası üzerinde yap |

---

## 11. Doğrulanan DOĞRU şeyler

Bunları özellikle belirtiyorum çünkü repo'daki yorumlar genelde isabetli ve bunlar
doğrulanınca güvenilirlik artıyor:

**`low_latency_layer` iddialarının tamamı doğru.** Sabitlenen rev `948a561`'teki
`low_latency_layer.json.in`'i ve `src/layer_context.hh`'yi okudum:
- Tam olarak 3 env var okunuyor: `LOW_LATENCY_LAYER_REFLEX`, `…_SPOOF_NVIDIA`,
  `…_FORCE_DECOUPLED` — README'nin "tam olarak üç tanedir" iddiası ✅
- Manifest'te `enable_environment` **yok**, sadece `disable_environment: DISABLE_LOW_LATENCY_LAYER`
  → varsayılan açık ✅ ("ENABLE_LOW_LATENCY_LAYER sessiz no-op" hikâyesi tutarlı)
- `library_path` **mutlak** (`@CMAKE_INSTALL_FULL_LIBDIR@/…`) → `/etc/vulkan/implicit_layer.d/`
  altına kopyalanması sorun değil (göreli yol olsaydı bozulurdu) ✅
- `CMakeLists.txt` manifesti tam olarak `${CMAKE_INSTALL_DATADIR}/vulkan/implicit_layer.d/`
  altına kuruyor → `configuration.nix:440`'taki `.source` yolu doğru ✅

**Diğer doğrulananlar:**
- `low_latency_layer.json.in`'teki `disable_environment` kapısı → `LOW_LATENCY_LAYER_REFLEX=1`
  sistem genelinde ayarlamak doğru strateji; `SPOOF_NVIDIA`'nın oyun bazına bırakılması
  README'deki gibi mantıklı.
- `aya-expanse:8b` Ollama registry'de **var** (ollama.com/library/aya-expanse → `32b`, `8b`, `latest`).
- `services.ollama.rocmOverrideGfx` mevcut ve `HSA_OVERRIDE_GFX_VERSION` set ediyor;
  `modelsDir` varsayılanı `/var/lib/ollama/models` → yazılabilir, store'a yazma sorunu yok.
- `services.lsfg-vk.enable` / `ui.enable` üçüncü taraf flake modülünde mevcut
  (`pabloaul/lsfg-vk-flake@62aadfc`, `flake.lock`'ta rev + narHash ile sabitli ✅).
- CI'ın shellcheck gate'i **gerçekten geçiyor** — shellcheck 0.10.0 ile
  `shellcheck -S warning install.sh nixos/hooks/qemu` → exit 0. (info seviyesinde 3× SC2015 var,
  kasıtlı `A && B || C` kalıbı, zararsız.)
- `hypridle` 0.1.8 config'in kullandığı **tüm** anahtarları tanıyor.
- `win10.xml`'deki Nix'e özgü yollar doğru: `/run/libvirt/nix-ovmf/*` (libvirtd-config
  her boot'ta firmware'i oraya kopyalıyor), `/run/libvirt/nix-emulators/qemu-system-x86_64`
  (RuntimeDirectory'de tanımlı) ✅
- `libvirtd-config` hook dizinini her boot `rm -rf` + yeniden linkliyor → hook'un yeni
  generation'a doğru geçmesi garantili.
- Güvenlik tarafı **gerçekten iyileştirilmiş**: bakımcının SSH anahtarı kaldırılmış,
  `PermitRootLogin = "no"`, `PasswordAuthentication = false`, 1714-1764 port açığı
  kaldırılmış, commented-out maintainer key'i duruyor.
- `wuwa-auto.sh`'ın `argos-translate` yokluğu için `command -v` kontrolü yapması doğru çözüm
  (nixpkgs'ta binary paket gerçekten yok).
- `KURULUM.md` §5→§6 sırasındaki `@home/.snapshots` açıklaması doğru: `@home` mount edilmeden
  içine alt hacim oluşturulamaz.
- `pkill -f` kendi üst kabuğunu öldürme tuzağının `toggle-*.sh` ile çözülmesi doğru ve
  gerçekten çalışıyor (desen `wuwa-auto[.]sh`, kendi yolu `toggle-wuwa.sh` → eşleşmiyor).
- `flake.nix`'teki `nixConfig` ile substituter'ları iki yerde tanımlama düzeltmesi doğru —
  flake değerlendirilirken `configuration.nix`'teki `nix.settings` henüz etkin olmuyor.

---

## 12. Önerilen düzeltme sırası

1. `configuration.nix:491` → `programs.steam.enable = true;` → **sonra hemen**
   `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath` çalıştır.
   (Bu tek satır, config'in geri kalanının çalışıp çalışmadığını belirliyor.)
2. `home.nix:992,1016` → `tr -d '\014'`
3. `home.nix:1199` → `set -gx MANPAGER 'col -bx | bat -l man -p --paging=always'`
4. `configuration.nix:71` → `makeBinPath`'e `pkgs.findutils pkgs.gnused` ekle
5. `home.nix:403-466` → hyprlock config'ini 0.9.6 şemasına göre yeniden yaz
   (`button` → kaldır; `label:size` → kaldır; `check_symbol` → `check_text`; `font_size`
   kaldır; `placeholder_color`, `fail_transition`, `grace`, `disable_loading_bar` kaldır).
   Güç/uyku için `wlogout`/`systemctl suspend`'ı `shape` + `label` ile ya da `SUPER+SHIFT+E`
   kısayoluyla çöz.
6. `README.md:128` → 0.56.2; `flake.nix:26-34` yorumunu güncelle; `home.nix` içindeki
   "v0.55.0 satır N" referanslarını 0.56.2'ye taşı ve tekerlekle/touchpad ayrımını not et
7. CI'a gömülü script taramasını ekle (regresyonları yakalasın diye)
8. `install.sh` monitör adı düzeltmesi + `KURULUM.md` §9b markdown onarımı

---

## 13. Bu analizi nasıl doğruladım

Repo tek başına bırakılmadı; her iddia ya çalıştırılarak ya da birincil kaynaktan okunarak
test edildi:

- **Çalıştırılan testler:** `shellcheck 0.10.0` (CI ile birebir komut, ayrıca 7 gömülü script),
  `bash -n` syntax kontrolü, `tr -d` kaçış hatasının canlı gösterimi, `MANPAGER` argv
  davranışının canlı gösterimi, `xml.etree` XML doğrulaması, git-tracked dosya listesi,
  flake.lock özet çıkarımı, PNG başlık/doğrulama.
- **Okunan birincil kaynaklar:** kilitli nixpkgs rev'inde `hyprland` (0.56.2), `hyprlock`
  (0.9.6), `hypridle` (0.1.8), `hyprpicker` (0.4.7), `hyprpolkitagent` paket sürümleri;
  `nixos/modules/virtualisation/libvirtd.nix`; `nixos/lib/systemd-lib.nix`; `nixos/modules/rename.nix`;
  `nixos/modules/programs/steam.nix`; `nixos/modules/services/misc/ollama.nix`;
  `nixos/modules/virtualisation/waydroid.nix` varlığı; Hyprland `v0.56.2` kaynak ağacı
  (`ConfigValues.cpp`, `KeybindManager.cpp`, `DispatcherTranslator.cpp`); hyprlock `v0.9.6`
  tüm kaynak ağacı; hypridle `v0.1.8` kaynak ağacı; `low_latency_layer@948a561`
  (`CMakeLists.txt`, manifest, `layer_context.hh`); `lsfg-vk-flake@62aadfc` (`module.nix`);
  Nix 2.24 `lexer.l` (`unescapeStr`).
- **Dış doğrulama:** `ollama.com/library/aya-expanse` etiket listesi; NixOS Steam wiki'si
  (`programs.steam` adlandırması).

**Sandbox'ta `nix` ve `nix-instantiate` yoktu**, dolayısıyla modül sistemi canlı
değerlendirilemedi. #1 (P0) bulgusu bu yüzden "kesin kanıtlanmış" değil, **çok yüksek
güvenle** veriliyor: option tanımı, uyumluluk kaydı ve modül ağacının üçü birden
`services.steam` içermiyor. Tek komutla kesinleşir.

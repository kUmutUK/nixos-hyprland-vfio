# `nixos-hyprland-vfio` (3. zip) — Bağımsız Kod & Yapılandırma Analizi

**İnceleme tarihi:** 2026-10-05
**Kaynak:** `nixos-hyprland-vfio(3).zip` (6.2 MB, shallow clone)
**Commit:** `97a1665` "Delete scripts/scripts" (tek commit, `.git/shallow`)
**Kapsam:** 21 dosya (19 metin = **5.684 satır**, 2 PNG). Hepsi satır satır okundu.

> Repoda `nixos-hyprland-vfio-analiz.md` (v2 raporu) ve `F-İX-MAN-İFEST.md` (v3 düzeltme listesi)
> zaten duruyor. Bu rapor onlardan **bağımsız**; onların iddialarını tek tek doğruladım ve
> **v3 düzeltmesinden sonra hâlâ duran / yeni ortaya çıkan** sorunları buldum.

---

## 0. Yönetici özeti

Bu, gerçekten emek harcanmış bir config. Yorumların büyük kısmı teknik olarak **isabetli** ve
iddiaların neredeyse tamamı doğrulandı (aşağıdaki "Doğrulanan doğrular" bölümü). Güvenlik
tarafı temiz: zararlı içerik, gizli anahtar, veri sızdırma yok.

Ama üç düzeyde sorun var:

1. **İki P1, ekranda görünür bozukluk üretir.** Kilit ekranında saat ve kullanıcı adı
   **literal `{H:M}` / `{user}` metni** olarak çiziliyor — hyprlock'ta `{}` formatı diye bir
   şey yok. Ve Hyprland 0.56.2 artık `hyprland.lua`'ya **öncelik veriyor**; o dosya bir gün
   PATH'te belirirse eldeki 250 satırlık `hyprland.conf` **sessizce tamamen yok sayılıyor**.
2. **Bir P2 grubu "çalışıyor gibi görünüyor ama yapmıyor":** yinelenmiş kilit ekranı label'ı,
   `exec-once` sıralama yarışı, monitör adının hâlâ hiç gömülmemiş olması, `hyprlock`
   label'larının PATH'e bağımlı komutları.
3. **Dokümantasyon kendi kuralını ihlal ediyor.** v3 düzeltmesi bir yorumdaki satır
   numarasını 0.56.2'ye taşırken aynı yorumdaki kardeş numaraları 0.55.0'de bırakmış.
   Düzeltilen bloktan geriye **iki kez tekrar eden label + yorum** kalmış.

### Bulgu tablosu (yeni)

| # | Bulgu | Şiddet | Yer |
|---|-------|--------|------|
| 1 | `{H:M}` / `{user}` hyprlock'ta geçersiz format → ekranda literal metin | **P1** | `home.nix:446,457` |
| 2 | Hyprland 0.56.2 `hyprland.lua`'ya öncelik veriyor; `.conf` sessizce yok sayılıyor | **P1** | `home.nix:154-410` |
| 3 | Kilit ekranı label'ı iki kez kopyalanmış (aynı pozisyon) | **P1** | `home.nix:479-484,492-497` |
| 4 | `exec-once` "sıralama" yorumu yanlış → watchdog yarışla 3 sn geç başlıyor | **P1** | `home.nix:402-409` |
| 5 | `hyprlandMonitorLine` hâlâ monitör adı içermiyor | **P2** | `home.nix:7`, `install.sh:151` |
| 6 | flake.lock'ta **iki** home-manager rev'i (kök + impermanence) | **P2** | `flake.lock` |
| 7 | `win10.xml`: x86_64 firmware + **i386** NVRAM şablonu | **P2** | `win10.xml:18-19` |
| 8 | swtpm dizini sahiplik servisinin kapsamı dışında | **P2** | `configuration.nix:491` |
| 9 | `virsh start` oturumu kendisi sonlandırıyor, hiçbir yerde uyarılmıyor | **P2** | `hooks/qemu:139` |
| 10 | hyprlock `cmd[]` label'ları `awk`/`date` gibi PATH'e bağımlı araç çağırıyor | **P2** | `home.nix:446-471` |
| 11 | `security.pam.services.hyprlock` yorumunun gerekçesi yanlış (satır doğru) | P3 | `configuration.nix:391` |
| 12 | 0.55.0'dan kalma iki satır referansı (`onMouseEvent`, `hyprland.conf:342`) | P3 | `home.nix:375,477,490` |
| 13 | `impermanence` bir tek dosya için import ediliyor | P3 | `flake.nix:44,61` |
| 14 | README repo ağacı güncel değil (`scripts/`, `.github/` yok) | P3 | `README.md:270` |
| 15 | Dosya adında Türkçe büyük noktalı İ: `F-İX-MAN-İFEST.md` | P3 | repo kökü |
| 16 | install.sh clone'u yerinde değiştirip `skip-worktree` ile gizliyor | P3 | `install.sh:207-266` |
| 17 | `low-latency-layer` `sha256`'ı hiç test edilmemiş | P3 | `configuration.nix:14` |
| 18 | waypaper (SUPER+W) mpvpaper ile çakışıyor | P3 | `home.nix:243` |
| 19 | Aynı anda 3 Vulkan implicit layer | P3 | `configuration.nix:425,447` |
| 20 | power-profiles-daemon ↔ ananicy ↔ gamemode üçlüsü | P3 | `configuration.nix:195,592,450` |

---

## 1. P1 — Kilit ekranında saat ve kullanıcı adı literal metin olarak çiziliyor

`home.nix:444-448` ve `home.nix:455-459`:

```hyprlock
label { position = 0, 150; ... text =  {H:M}; ... }
label { position = 0,  10; ... text =  {user}; ... }
```

**hyprlock 0.9.6'da `{}` diye bir format dili yok.** Birincil kaynak —
`hyprlock v0.9.6 · src/renderer/widgets/IWidget.cpp · IWidget::formatString()`:

```cpp
replaceInString(in, "$DESC", ...);
replaceInString(in, "$USER", ...);
replaceInString(in, "<br/>", "\n");
if (in.contains("$TIME12")) { ... }
if (in.contains("$TIME"))   { ... }
if (in.contains("$ATTEMPTS")) { ... }
if (in.contains("$LAYOUT"))   { ... }
if (in.contains("$FAIL"))     { ... }
if (in.contains("$PAMFAIL") / "$PAMPROMPT" / "$FPRINTFAIL" / "$FPRINTPROMPT") { ... }
if (in.starts_with("cmd[")) { /* update:N */ }
```

`{` hiç geçmiyor. Pango işaretlemesi de `<b>`/`<i>` kullanıyor. Yani iki label de ekrana
**tam olarak `{H:M}`** ve **`{user}`** yazar.

Bu, v3 düzeltmesinin kör noktası: hyprlock 0.9.6 şeması için `button`, `grace`,
`check_symbol`, `font_size` gibi **anahtar adları** tek tek doğrulandı — ama bir
**değerin** format dili hiç kontrol edilmedi.

**Düzeltme:**
```hyprlock
text = $TIME;     # 24 saat, dakika çözünürlüğünde (getTime24h())
text = $USER;     # kullanıcı adı
```
`$TIME` kullanıldığında `formatString` `updateEveryMs`'i 1000'e çekiyor, yani saat canlı
güncelleniyor. `font_size = 80` label için de geçerli (label `font_size`'ı destekliyor).

> Bonus (kullanılmayan bir yetenek): 0.56.2'de `KeybindManager.cpp:464-468` **yatay** tekerlek
> için `mouse_left` / `mouse_right` de üretiyor. Config'te hiç bağlı değil — yatay tekerlekle
> pencere geçişi isteyenler için boş bir alan.

---

## 2. P1 — Hyprland 0.56.2 `hyprland.lua`'ya öncelik veriyor

Bu, paketin en büyük ileri-uyumluluk riski ve **hiçbir dosyada geçmiyor**.

`Hyprland v0.56.2 · src/config/supplementary/jeremy/Jeremy.cpp · getMainConfigPath()`:

```cpp
const auto LUA_PATHS  = Hyprutils::Path::findConfig("hyprland", "lua");
const auto CONF_PATHS = Hyprutils::Path::findConfig("hyprland", "conf");

if (LUA_PATHS.first.has_value())            return ...lua...;   // ← ÖNCE LUA
else if (CONF_PATHS.first.has_value())       return ...conf...;
else if (LUA_PATHS.second.has_value())       return ...lua...;   // XDG_CONFIG_DIRS
```

ve `src/config/ConfigManager.cpp`:

```cpp
if (filePath.extension() == ".lua") g_mgr = makeUnique<Lua::CConfigManager>();
else { filePath.replace_extension(".conf"); g_mgr = makeUnique<Legacy::CConfigManager>(); }
```

**Anlamı:** eldeki `hyprland.conf` şu an yalnızca **hiçbir yerde `hyprland.lua` yok**
diye çalışıyor. `~/.config/hypr/`, `~/.config`, `/etc/xdg/` altına herhangi bir
`hyprland.lua` düşerse — kullanıcı örnek config'i kopyalarsa, Hyprland bir gün otomatik
üretirse, `<pkg>/share/hypr/hyprland.lua` yanlışlıkla XDG_CONFIG_DIRS'a girerse — **250
satırlık config sessizce tamamen yok sayılır.** Hata yok, uyarı yok, `hyprctl` boş config'i
gösterir.

Ek olarak, 0.56.2'nin `src/config/legacy/DefaultConfig.hpp` içindeki `EXAMPLE_CONFIG`
**10 satırlık bir stub** ve kendisi şunu diyor:

```
# This config is a STUB! This should never be generated.
# Use the default lua config from .../Hyprland/blob/main/example/hyprland.lua
```

Hatta stub'daki `bind` sözdizimi bile yeni (`bind = $mainMod, C, killactive,` — sonunda
virgül, `exec` anahtar kelimesi yok). Yani **legacy yol bakım modunda**, yeni yol
kazanıyor.

**Öneri (kod değiştirmeden önce):**
1. README'ye bir uyarı kutusu: *"Bu config `hyprland.conf` kullanıyor. Hyprland 0.57+ Lua
   config'e geçiyor. `hyprland.lua` dosyası PATH'te bulunursa bu config sessizce
   devre dışı kalır."*
2. `nix flake update` sonrası CI'a ekle: `hyprctl version` çıktısı + config yolu kontrolü.
   Ya da daha basit — `nix eval` sonrası bir assertion:
   ```nix
   assert !builtins.pathExists ./hyprland.lua;
   ```
3. Gerçek çözüm: `hyprland.lua`'ya geçiş. Ama o zaman `windowrule`, `bindm`, `binde`,
   `exec-once` hepsi yeniden yazılır — ayrı bir iş, acele etmemek gerekir.

---

## 3. P1 — Kilit ekranı label'ı iki kez kopyalanmış

`home.nix:479-484` ile `home.nix:492-497` **byte-byte aynı**. Üstelik yorum da iki kez
tekrarlanmış (`home.nix:472-478` ve `485-491`).

```hyprlock
    label {
        position = 0, -260; halign = center; valign = center;
        text = oturumu kapatmak icin: SUPER + SHIFT + E
        font_family = JetBrainsMono Nerd Font; font_size = 14;
        font_color = rgba(255, 255, 255, 0.35); shadow_passes = 0;
    }
```

`hyprlock` 8 adet `label` bloğu görüyor, ikisi de aynı pozisyonda → aynı yere iki kez
çiziliyor (0.35 alfa üst üste binince metin daha "kalın" görünür). Görsel olarak çok
rahatsız etmese de **v3 düzeltmesinin bıraktığı bir kopyalama hatası** — `button`
bloklarının ikisi birden düzeltilirken yorumu da yapıştırılmış.

**Düzeltme:** ikinci bloğu (492-497) ve ikinci yorumu (485-491) sil.

---

## 4. P1 — `exec-once` "sıralama" düzeltmesi yarış bırakıyor

`home.nix:402-409`:

```hyprland
# Düzeltme (2026-10-04): ... AYRICA bu satır mpvpaper-watchdog'u BAŞLATAN
# satırın ALTINDAYDI; import önce, başlatma sonra olacak şekilde sıralandı.
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_DISPLAY
exec-once = systemctl --user start mpvpaper-watchdog gamemode-notify
```

**Hyprland `exec`/`exec-once`'i `/bin/sh -c` ile fork edip beklemez.** İki satır arka arkaya
spawn edilir, pratikte **aynı anda** çalışır. "Sıraladık" yorumu gerçeği yansıtmıyor.

Sonuç: `import-environment` bitmeden `mpvpaper-watchdog` başlayabilir → sokette
`$HYPRLAND_INSTANCE_SIGNATURE` yok → `[ -S "$HYPR_SOCK" ]` false → `exit 1`
(`home.nix:1189-1199`). `Restart = on-failure` + `RestartSec = 3` yüzünden **kendiliğinden
iyileşiyor**, ama her login'de bir failed unit + ~3 sn geç duvar kağıdı watchdog'u. Aynı
şekilde `gamemode-notify` de `dbus-monitor`'e bağlanmada erken kalkabilir.

**Düzeltme (tek `exec-once`, sıralama garantili):**
```hyprland
exec-once = sh -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_DISPLAY; systemctl --user start mpvpaper-watchdog gamemode-notify'
```
Daha temiz alternatif: iki servisi de `graphical-session.target`'a `wantedBy` verip
`After = ["systemd-user-sessions.service"]` koymak; `hyprland.conf`'den tamamen çıkarmak.
Home Manager `systemd.user.services` zaten `Install.WantedBy` destekliyor.

---

## 5. P2 — `hyprlandMonitorLine` hâlâ monitör adı içermiyor

`home.nix:7`:
```nix
hyprlandMonitorLine = "monitor = ,preferred,auto,1";
```
`install.sh:151-152`:
```bash
read -rp "Hyprland monitor line (e.g. monitor = ,2560x1440@170,auto,1) [monitor = ,preferred,auto,1]: " hypr_mon_line
hypr_mon_line="${hypr_mon_line:-monitor = ,preferred,auto,1}"
```

`install.sh` monitör adını soruyor (`:147`) ama o değer **sadece** `monitorOutput`'a
(mpvpaper) gidiyor. Hyprland satırına **hiç gömülmüyor** — kullanıcıya gösterilen örnek bile
boş ad içeriyor. Hyprland'da boş monitör adı = *"bu kuralı tüm monitörlere uygula"*.

2560x1440@170 panelli bir oyun kurulumunda `monitor = ,2560x1440@170,auto,1` yazılsa bile
ad yine boş kalır, kural yine her çıkışa uygulanır. `vrr = 2` + `allow_tearing = true` ile
birlikte bu, yanlış çözünürlük/Hz'e düşme riski demek.

**Düzeltme:**
```bash
read -rp "Monitor adı (örn. DP-3): " input_mon_name
[[ -n "$input_mon_name" ]] && hypr_mon_line="monitor = ${input_mon_name},preferred,auto,1"
```

---

## 6. P2 — flake.lock'ta iki ayrı home-manager rev'i

`flake.lock` gerçekte şöyle:

| node | kaynak | not |
|------|--------|-----|
| `nixpkgs_3` | NixOS/nixpkgs @ `7a0f122f5090` | **kök** (flake.nix `nixpkgs.url`) |
| `nixpkgs` | NixOS/nixpkgs @ `3b4545497180` | cachyos-kernel'ın kendi nixpkgs'i |
| `home-manager` | home-manager @ `7b4c5ec4beda` | kök (`nixpkgs.follows` ✓) |
| `home-manager_2` | home-manager @ `c47b2cc64a62` | **impermanence'ın getirdiği** |
| `impermanence` | impermanence @ `7b1d382faf60` | `nixpkgs.follows` ✓, `home-manager` follow **yok** |

`impermanence.nixosModules.impermanence`, kendi Home Manager modülünü
`home-manager.sharedModules`'e enjekte ediyor. Yani `home.persistence` option'ını
**HM @7b4c5ec4beda** değerlendiriyor ama tanımlayan modül **HM @c47b2cc64a62** için
yazılmış. İki HM arasındaki sürüm farkı tam olarak "the option X does not exist" sınıfı
sessiz kırılmalar üretir. `flake.nix` `impermanence.inputs.nixpkgs.follows` tanımlıyor ama
`impermanence.inputs.home-manager.follows` **tanımlı değil**.

Ayrıca CHANGELOG'daki "flake.lock'ta üç ayrı nixpkgs kopyası var (`nixpkgs_3` kök,
`nixpkgs` cachyos-kernel, `nixpkgs_2` hyprland)" maddesi **bayat**: hyprland input'u 1.2.2'de
kaldırıldığı için artık **iki** nixpkgs var. Dokümanı düzeltin ki gereksiz "sadeleştirme"
işine girişmesinler.

**Düzeltme:**
```nix
impermanence.inputs.nixpkgs.follows    = "nixpkgs";
impermanence.inputs.home-manager.follows = "home-manager";
```
(veya tamamen kaldır — bkz. bulgu 13).

---

## 7. P2 — `win10.xml`: x86_64 firmware + i386 NVRAM şablonu

```xml
<loader readonly="yes" type="pflash" format="raw">/run/libvirt/nix-ovmf/edk2-x86_64-code.fd</loader>
<nvram template="/run/libvirt/nix-ovmf/edk2-i386-vars.fd" templateFormat="raw" format="raw">/var/lib/libvirt/qemu/nvram/win10_VARS.fd</nvram>
```

Kod **64-bit** OVMF, değişken deposu şablonu ise **IA32** OVMF build'i. `win10.xml`
`arch="x86_64"`, yani eşleşmiyor. OVMF'te x86_64 misafir için doğru eşleme
`edk2-x86_64-code.fd` + `edk2-x86_64-vars.fd`'dir.

İyi haber: her iki dosya da `/run/libvirt/nix-ovmf` altında **var**. nixpkgs'in
`libvirtd-config` servisi qemu'nun firmware JSON'larındaki `mapping.executable.filename` ve
`mapping."nvram-template".filename` alanlarının birleşimini kopyalıyor:

```
readarray -t firmware_files < <( jq -rs '[.[] | .mapping.executable.filename,
                                            .mapping."nvram-template".filename] | unique | .[]' \
                                     ${qemu.package}/share/qemu/firmware/* )
cp -sfv "${firmware_files[@]}" /run/libvirt/nix-ovmf
```

Yani dosya eksik değil, **yanlış** dosya. Çoğu durumda açılır (değişken deposu başlık
arkitektürden bağımsız), ama yanlış eşleşmenin klasik belirtileri misafirde "yeni kurulum
olarak görünme", değişken kaybı / Secure Boot anahtarı uyuşmazlığı. Secure Boot burada
kapalı, dolayısıyla risk düşük — ama düzeltmesi tek kelime:
`edk2-i386-vars.fd` → `edk2-x86_64-vars.fd`.

---

## 8. P2 — swtpm dizini sahiplik servisinin kapsamı dışında

`configuration.nix:483-497` her boot'ta şunları `qemu-libvirtd`'ya veriyor:

```bash
for d in /var/lib/libvirt/images /var/lib/libvirt/qemu; do
  chown -R qemu-libvirtd:qemu-libvirtd "$d" || true
done
```

Ama aynı config'de `qemu.runAsRoot = false` **ve** `qemu.swtpm.enable = true`, ve
`win10.xml:181-185` bir `<tpm model="tpm-crb">` tanımlıyor. swtpm de `qemu-libvirtd`
 olarak koşuyor ve `/var/lib/libvirt/swtpm/<uuid>/` altında durum dosyası yazması gerekiyor.
libvirtd root olarak o dizini açsa bile 0755/root:root ise swtpm yazamaz.

Aynı sebepten `nvram` (`/var/lib/libvirt/qemu/`) kapsama alınmış — yani mantık doğru,
sadece **bir dizin eksik**. Döngüye ekleyin:

```bash
for d in /var/lib/libvirt/images /var/lib/libvirt/qemu /var/lib/libvirt/swtpm; do
```

> Dürüstlük notu: libvirt'in `qemuStatePrepareHost()`'u bazı sürümlerde state dizinlerini
> zaten doğru kullanıcıyla oluşturuyor olabilir. Bu yüzden "ilk `virsh start`'ta kesin
> hata verir" demiyorum — **çalışma zamanında doğrulanmalı** (`ls -ld /var/lib/libvirt/swtpm`).
> Ama `images`/`qemu`'yu kapsayan bir servisin `swtmp`'yi atlama sebebi yok.

---

## 9. P2 — VM'i başlatmak oturumu kendisi sonlandırıyor

`hooks/qemu:136-140` (`stop_hyprland` içinde):

```bash
loginctl terminate-user "${HOST_USER:-localhost}" 2>/dev/null || true
loginctl terminate-seat seat0 2>/dev/null || true
```

Masaüstünde açıkken `virt-manager`'dan ya da terminalden `virsh start win10` çalıştırırsan,
**o oturumun kendisi sonlandırılıyor** — yani komutu veren istemci de ölüyor. libvirtd
tarafındaki iş devam eder (RPC bir kere iletilmiştir), bu yüzden çoğu zaman "çalışıyor"
gibi görünür; ama istemci sonucu hiç gösteremez, `virt-manager` arayüzü kapanır.

Hiçbir dokümanda uyarı yok — README ve KURULUM bölümünde sadece "ekran kararır (normal)"
yazıyor. Pratik çözümler:
```bash
# ayrı TTY'den
sudo systemctl start libvirtd && virsh start win10
# ya da oturumdan bağımsız
systemd-run --scope --unit=vmstart virsh start win10
```
KURULUM §9b'ye bu notu eklemek gerekir.

---

## 10. P2 — `hyprlock` `cmd[]` label'ları PATH'e bağımlı

`home.nix:460-471`'deki iki label komut çalıştırıyor:
```hyprlock
text = cmd[update:2000, wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f%%", $2*100}'];
text = cmd[update:5000, nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null | ... | xargs -I{} echo " {}" || echo " Bağlı Değil"];
```

hyprlock bu komutları kendi süreç PATH'iyle `/bin/sh -c`'ye veriyor. `wpctl` ✓ ve `nmcli` ✓
`environment.systemPackages`'ta var. **`awk` yok.** `/run/current-system/sw/bin` yalnızca
`environment.systemPackages`'ta **açıkça yazılmış** paketlerin ikililerini içerir; `gawk`/`mawk`
yazılı değil.

Bu, repoda zaten öğrenilmiş bir ders — CHANGELOG 1.2.0: *"mpvpaper-watchdog systemd PATH'inde
`awk` yoktu, script `awk` kullanıyordu → `pkgs.gawk` eklendi"* — ama hyprlock label'larına
aynı tedavi uygulanmamış. `home.nix:1417-1423` `brightnessctl`'i, `:1410` `hyprctl`'i
mutlak store yoluyla çağırıyor; label'larda da aynısı yapılmalı:
`text = cmd[update:2000, ${pkgs.wireplumber}/bin/wpctl ... | ${pkgs.gawk}/bin/awk ...]`.

> `cmd[...]` ayrıştırmasında zararsız iki gürültü var, çalıştırmıyor: (a) `]`'den sonra gelen
> `;` komutun sonuna ekleniyor (`; cmd` geçerli bir kabuk); (b) virgülle ayrılmış ikinci
> parça `Unknown prop in string format` logu basıyor. Zararsız, dokunmayın.

---

## 11. P3 — `security.pam.services.hyprlock` yorumunun gerekçesi yanlış

`configuration.nix:386-394`:
```nix
# NOT (2026-10-04): `backend = "pam_unix.so"` CI'da ... hatası verdi ...
# Boş attrset bırakılıyor: systemd.services.hyprlock bunu okuyup
# /etc/pam.d/hyprlock'u üretir, varsayılan PAM stack'i (pam_unix) kullanılır.
security.pam.services.hyprlock = { };
```

**Satır doğru, gerekçe üç ayrı yerde yanlış:**

1. `programs.hyprlock` bu config'de **hiç enable edilmiyor** (grep'te yok). Yani
   `systemd.services.hyprlock` diye bir şey **yok**. hyprlock yalnızca
   `environment.systemPackages`'taki ikiliden ve `SUPER+Escape` kısayolundan geliyor.
2. `/etc/pam.d/hyprlock`'u üreten modül `security.pam`
   (`nixos/modules/security/pam.nix`) — hyprlock'un systemd servisi değil.
3. "Boş attrset → varsayılan stack" mantığı pam alt modülünün varsayılanlarından geliyor:
   `useDefaultRules = true` (default) ve `unixAuth = true` (default) →
   `auth … pam_unix.so sufficient`, `auth … pam_env.so`, `session … pam_systemd.so` vb.
   `{}` yazmanın özel bir "doldurma" anlamı yok.

Satırın kendisi **kanonik NixOS reçetesi** — Home Manager'ın hyprlock dokümanı bile
"on NixOS it can be enabled using: `security.pam.services.hyprlock = {}`" diyor. Doğrulama:
```bash
ls -l /etc/pam.d/hyprlock && grep -c pam_unix /etc/pam.d/hyprlock
```
Yorum düzeltilmeli, çünkü ileride biri `useDefaultRules = false` yazarsa ve "boş attrset
yeterli" mantığıyla devam ederse kilit ekranı **hiç açılmaz**.

---

## 12. P3 — 0.55.0'dan kalma iki satır referansı

v3 düzeltmesi `home.nix:250-252`'de şunu yaptı:
> *"DÜZELTME (2026-10-05): … satırlar KAYDI: `KeybindManager::onAxisEvent` artık
> `KeybindManager.cpp:446-470`."* → **doğru** (v0.56.2'de tam olarak 446).

Ama aynı bölümdeki kardeş referanslar güncellenmemiş:

| Yer | Yazan | Gerçek (v0.56.2) |
|-----|-------|------------------|
| `home.nix:375` | `onMouseEvent() (KeybindManager.cpp:438-448)` | **477-488** (`"mouse:" + std::to_string(e.button)` `:488`'de) |
| `home.nix:477` | `SUPER+SHIFT+E -> hyprctl exit (hyprland.conf:342)` | binding `:351`'de |
| `home.nix:490` | aynı yorum ikinci kez | aynı |

Yani düzeltme geçtiği yorum bloğunda **üç referanstan birini** güncellemiş. Reponun tüm
değer önerisi "kaynak satır numarası ver" olduğu için bu, tam da bu repoyu okuyan birinin
en çok dikkat edeceği türden bir tutarsızlık.

---

## 13. P3 — `impermanence` bir tek dosya için import ediliyor

`flake.nix:44-45,61` impermanence'i NixOS modülü olarak import ediyor. Ama
`configuration.nix:598-623` kendi yorumunda anlatıyor: NixOS tarafında
`environment.persistence` **yok**, denendi ve geri alındı. Geriye kalan tek kullanım:

```nix
home.persistence."/nix/persist/home" = { files = [ ".config/lsfg-vk/conf.toml" ]; };
```

Yani tüm zincir (impermanence flake input'u → HM modülü sürüm kayması → rebuild'de her seferinde
"Neither /var/lib/nixos nor any of its parents are persisted" uyarısı) tek bir lsfg-vk shader
önbelleği dosyası için. Bulgu 6'daki HM sürüm kayması da aynı import'tan geliyor.

Ucuz alternatif: `home.file` + basit bir `systemd.tmpfiles.rules` dizini, impermanence tamamen
çıkarılır → rebuild uyarısı ve HM sürüm riski birlikte biter.

---

## 14. P3 — README repo ağacı güncel değil

`README.md:270-288` "Repository Structure" bölümü `scripts/`, `.github/`,
`nixos-hyprland-vfio-analiz.md` ve düzeltme manifestini **listelemiyor**. v3 geçişinde CI'a
eklenen `scripts/extract-embedded-scripts.py` adımı doğrudan bu dosyaya bağımlı — yani
README, CI'ın çalışması için gerekli dosyayı yok sayıyor.

---

## 15. P3 — Dosya adında Türkçe büyük noktalı İ

`git ls-files` çıktısı:
```
"F\304\260X-MAN\304\260FEST.md"
```
`C4 B0` = U+0130 = **`İ`**. Yani dosya adı `F-İX-MAN-İFEST.md`, ASCII "FIX-MANIFEST.md" değil.
Git'te bu haliyle commit edilmiş, terminalde de öyle görünüyor. Kim bir yerde
`FIX-MANIFEST.md` yazarsa (CI path, PR açıklaması, `git mv`) eşleşmez. UTF-8 olmayan
terminallerde ayrıca mojibake olarak görünüyor (bu analiz sırasında konsol `F-<0xA6>X-MAN-<0xA6>FEST.md`
gösterdi — ISO-8859-9'da 0xA6 = `İ`).

Ayrıca: `nixos-hyprland-vfio-analiz.md` (v2 raporu) ve bu manifest **proje dokümanı değil**,
eski analiz artefaktları. Kökte duruyorlar ve artık kodla **çelişiyorlar** — analiz.md §12'deki
düzeltme listesi v3'te uygulanmış durumda, yani o rapor bugün "açık bulgular" diye listelenen
şeyleri artık düzeltilmiş gösteriyor. Bunları `docs/archive/` altına taşımak (veya silmek) gerekir.

---

## 16. P3 — `install.sh` clone'u yerinde değiştirip gizliyor

`install.sh:223-269` XML'i **reponun kendi** `vm-xml/win10.xml` dosyasını yerinde
değiştiriyor, sonra `git update-index --skip-worktree vm-xml/win10.xml` uyguluyor
(`:262-265`). Aynı desen `hooks/qemu` için de (`:207-212`).

Bu, CHANGELOG 1.2.2'de *"install.sh git çalışma ağacını kirletiyordu"* gerekçesiyle
"düzeltilmiş"ti — ama çözüm değişikliği gizlediği için daha kötü: artık `git status`,
`git diff` ve CI o iki dosyadaki gerçek yerel farkı **göremez**, ve sonraki `git pull`
conflict verir. Çalışma kopyası üzerinde yapın.

---

## 17. P3 — `low-latency-layer` `sha256`'ı hiç test edilmemiş

`configuration.nix:14`:
```nix
sha256 = "sha256-iUdcNnmY4NqaEnhoJUn7KEKTFQrlqo4tYOkLwEhmL+s=";
```

CHANGELOG 1.2.1'in kendi "runtime'da doğrulanmamış" listesinde duruyor ve **hâlâ öyle**.
Bu tek satır, config'in geri kalanının çalışıp çalışmadığını belirleyen ilk şey: hash yanlışsa
`nix eval` geçer, `nixos-rebuild` **ilk gerçek derlemede** patlar. Kullanıcının ilk denemesinde
çıkması demek. Tek komutla doğrulanır:

```bash
cd /etc/nixos/nixos
nix build .#nixosConfigurations.nixos.config.environment.systemPackages 2>&1 | tail
# ya da doğrudan:
nix-prefetch-url --unpack https://github.com/Korthos-Software/low_latency_layer/archive/948a5611f7c7a0568f1685e82df9f7bfbddb3f18.tar.gz --print-path
```

---

## 18. P3 — `waypaper` ↔ `mpvpaper` çakışması

`home.nix:243`: `bind = $mainMod, W, exec, ${pkgs.waypaper}/bin/waypaper`

Aynı oturumda `mpvpaper.service` arka planda video duvar kağıdı çiziyor
(`home.nix:1443-1458`). waypaper statik duvar kağıdı *set* eder; ikisi aynı anda çalışınca
sonucu hangisinin kazandığı belirsiz. `waypaper`'ın ya kaldırılması ya da `mpvpaper`'ın
tek kaynak olması gerekir. (Dahası: `waypaper` GUI'si `SDL/GTK` üzerinden GPU açıyor —
VFIO öncesi `stop_hyprland` bunu yakalıyor, sonrasında sorun yok; ama gereksiz bir
yüzey.)

---

## 19. P3 — Aynı anda üç Vulkan implicit layer

`environment.systemPackages`'ta `vkbasalt` (`configuration.nix:410`),
`low-latency-layer` + `environment.etc."vulkan/implicit_layer.d/low_latency_layer.json"`
(`:425`, `:447`) ve üçüncü taraf `lsfg-vk-flake` modülü (`:97-100`) → aynı anda **üç** implicit
layer. Üçü de present-mode / frame üretimine müdahale ediyor. "Düşük gecikme" iddiası
teknik olarak birbiriyle çelişen üç katmanın üst üste binmesiyle sağlanıyor olabilir.
v3'te "bilinçli olarak ertelendi" yazıyor, ama düşük gecikme hedefi olan bir config için bu
gerçek bir deney sorunudur. Öneri: oyun başlatma seçeneklerine `vkbasalt`'ı yalnızca
VKBasalt'ın işe yaradığı oyunlarda ekleyin.

---

## 20. P3 — Üç CPU/governor yöneticisi aynı anda

| Bileşen | Ne ayarlıyor |
|---------|--------------|
| `services.power-profiles-daemon` (`:195`) | AMD pstate governor (`performance`/`balanced`) |
| `services.ananicy` + `ananicy-rules-cachyos` (`:592-596`) | governor **ve** sched policy (CachyOS kuralları `scx`-BORE varsayıyor) |
| `programs.gamemode` (`:450-475`) | renice/ioprio + `amd_performance_level = high` |

`amd_pstate=active` ile üçü de aynı alana yazıyor. `power-profiles-daemon` özellikle
"performance" profilini bir anda geri alabilir (ör. batarya eşiği, `powerprofilesctl` çağrısı,
ekran kilitleme). Oyun sırasında "performans düştü" şikâyetlerinin klasik kaynağı.
En azından `powerprofilesctl` hook'unu oyuncu/servis başlangıcında `performance`'a
çekecek bir `systemd` servisi ya da gamemode `custom` komutu düşünmeli.

---

## 21. Diğer gözlemler (P3/P4)

| Konu | Tespit | Öneri |
|------|--------|-------|
| `install.sh` sed enjeksiyonu | `:202-205`, `:334` kullanıcı girdisini ham koyuyor; `\|` veya `&` içeren değer bozar, `&` "eşleşen metin" anlamına gelir | `&`/delimiter kaçışı veya girdi doğrulaması (`^[0-9a-fA-F:.]+$`) |
| `users.users.localhost` | "localhost" yasal ama kafa karıştırıcı; `$USER=localhost` olan araçlar/`/etc/hosts` çakışmaları | En azından README'de "kullanıcı adı değiştirmek isterseniz 3 dosyada geçiyor" notu |
| `system.stateVersion = "26.05"` | unreleased/fresh sürüm; `update-users-groups.pl` "higher than any previously known version" uyarısı verebilir | Kurulumda gerçek release'e göre ayarla |
| `nix.settings.auto-optimise-store = true` | Her GC'dan sonra tüm store taranır; 800 GB disk + `keep-outputs/keep-derivations = true` → disk şişmesi | `auto-optimise-store = false` + ara sıra `nix store optimise` |
| `waybarStyle` ölü CSS | `#battery` stili var, `modules-right`'ta battery modülü yok | Zararsız, dokunma |
| `home.packages` / `systemPackages` çakışması | `libnotify`, `hyprpicker` her iki listede | Zararsız |
| `mpvpaper` `ConditionPathExists` | Video yoksa servis "skip" olur; gamemode'un stop/start çağrıları no-op | README'de "video yolunu ayarla" notu zaten var ✓ |
| `snapper` `TIMELINE_LIMIT_HOURLY = 10` × root+home | ~2 saatte bir iki snapshot + `NUMBER_LIMIT = 50` | Disk kullanımı izlenmeli |
| `.gitignore` `hashedPassword` | Doğru; ama `KURULUM.md` §8'de `install -d -m 755 /mnt/etc/nixos` + `tee` + `chmod 600` — üç komut yerine `install -m 600 /dev/stdin` daha temiz | Kozmetik |
| `extractor` `lines.index(line)` | `MARKERS`/`DIRECT_MARKER` desenleri satır başına özgün, dolayısıyla `index()` ilk eşleşmeyi bulur — doğru, ama O(n²). 1500 satırda önemsiz | Not düşmeye değmez |

---

## 22. Doğrulanan DOĞRU şeyler

Bunları özellikle yazıyorum çünkü repo iddialarının çoğu gerçekten doğru ve
**yanlış "düzeltme" yapılmasını önlemek** için gerekli.

**Sürüm iddiaları — kilitli nixpkgs `7a0f122f5090` paket dosyalarından birebir doğrulandı:**

| Paket | nixpkgs `pkgs/by-name/…/package.nix` |
|-------|----------------------------------------|
| hyprland | `version = "0.56.2"` ✓ |
| hyprlock | `version = "0.9.6"` ✓ |
| hypridle | `version = "0.1.8"` ✓ |
| hyprpicker | `version = "0.4.7"` ✓ |
| hyprpolkitagent | `version = "0.1.3"` ✓ |
| pyprland | `version = "3.4.4"` ✓ |

**hyprlock 0.9.6 şeması — v3 düzeltmesi %100 doğru.**
`v0.9.6/src/config/ConfigManager.cpp`'teki kayıtlar:
- Widget kategorileri **yalnızca** `background`, `shape`, `image`, `input-field`, `label` →
  **`button` gerçekten kaldırılmış** ✓ (iki buton hiç oluşmuyordu, iddia doğru)
- `general:` altında `text_trim`, `hide_cursor`, `ignore_empty_input`, `immediate_render`,
  `fractional_scaling`, `screencopy_mode`, `fail_timeout` var → **`grace` ve
  `disable_loading_bar` yok** ✓, **`hide_cursor` var** ✓ (config'in bıraktığı doğru)
- `input-field:` altında `check_text` **var** ✓, `font_size` **yok** ✓,
  `check_symbol` **yok** ✓, `placeholder_color` **yok** ✓, `fail_transition` **yok** ✓
- `label:` altında `size` **yok** ✓ (`position`, `color`, `font_size`, `text`, `font_family`,
  `halign`, `valign`, `rotate`, `text_align`, `zindex` + `shadow_*` + `onclick`)
- Yeni ve kullanılmayan: `auth:` bölümü (`auth:pam:enabled = 1`, `auth:pam:module = "hyprlock"`
  varsayılan) → `security.pam.services.hyprlock = {}` ile üretilen dosya tam olarak
  okunacak olan dosya ✓
- Hata davranışı: `if (result.error) Log::ERR "Proceeding ignoring faulty entries"` →
  config çalışmaya devam ediyor, "sessiz" değil ama ölümcül de değil ✓

**Hyprland 0.56.2 tuş iddiaları — hepsi doğru.**
`v0.56.2` kaynak ağacından:
- `src/managers/KeybindManager.cpp:446` `onAxisEvent` ✓ (yorumdaki 446-470 **doğru**)
- `:459` `if (e.source == WL_POINTER_AXIS_SOURCE_WHEEL && e.axis == …VERTICAL_SCROLL)` ✓
  → **dokunmatik panelde `SUPER+tekerlek` çalışmaz** uyarısı birebir doğru ve çok değerli
- `:461/:463` `mouse_down` / `mouse_up` ✓ → `bind = $mainMod, mouse_down, cyclenext` doğru
- `:477` `onMouseEvent`, `:488` `"mouse:" + std::to_string(e.button)` ✓ → `bindm … mouse:272/273`
  doğru (BTN_LEFT/BTN_RIGHT, `movewindow`/`resizewindow`)
- `src/config/legacy/DispatcherTranslator.cpp:475-479` `cyclenext` + `prev/p/last/l` ✓
- `KeybindManager.cpp:79-80` dispatcher listesinde `cyclenext` var, `cycleprev` **yok** ✓

**`hyprland.conf` — 22 anahtarın 22'si de 0.56.2'de kayıtlı.**
`v0.56.2/src/config/values/ConfigValues.cpp` içinde tek tek arandı, hepsi bulundu:
`session_lock_xray`, `enable_swallow`, `allow_session_lock_restore`, `no_focus_fallback`,
`resize_on_border`, `render_power`, `accel_profile`, `disable_splash_rendering`,
`force_default_wallpaper`, `animate_manual_resizes`, `swallow_regex`, `no_hardware_cursors`,
`inactive_timeout`, `disable_hyprland_logo`, `mouse_move_enables_dpms`,
`key_press_enables_dpms`, `smart_resizing`, `dim_inactive`, `allow_tearing`, `sensitivity`,
`follow_mouse`, `vrr`, `swallow_regex`, `binds:scroll_event_delay`. **Config'de geçersiz tek bir
Hyprland anahtarı yok.**

**pyprland 3.4.4 config yolu — v2 düzeltmesi doğru.**
`pyprland/constants.py:45-47`:
```python
OLD_CONFIG_FILE    = ~/.config/hypr/pyprland.json
LEGACY_CONFIG_FILE = ~/.config/hypr/pyprland.toml
CONFIG_FILE        = ~/.config/pypr/config.toml   # New canonical location
```
`home.nix`'in `pypr/config.toml` yazma kararı ve yorumu doğru.

**libvirt tarafı — hepsi doğrulandı.**
`nixos/modules/virtualisation/libvirtd.nix` (nixos-unstable):
- Hook dizini `/var/lib/libvirt/hooks/qemu.d/` ✓ → `virtualisation.libvirtd.hooks.qemu.vfio` doğru seçim
- `subDirs = [ "nix-emulators" "nix-helpers" "nix-ovmf" ]` → `win10.xml`'deki
  `/run/libvirt/nix-emulators/qemu-system-x86_64` ve `/run/libvirt/nix-ovmf/*` yolları gerçek ✓
- `path = [ qemu netcat ] ++ optional vswitch ++ optional swtpm` → hook'un PATH probleminin
  kaynağı doğrulandı, `pkgs.findutils` + `pkgs.gnused` eklenmesi **doğru düzeltme** ✓
- greetd: nixpkgs `greeter` kullanıcısını **ve** `/etc/pam.d/greetd`'yi kendisi üretiyor ✓
  (tuigreet kimlik doğrulaması çalışır, `services.greetd.settings.default_session.user = "greeter"`
  default olduğu için config'in yazması da doğru)

**`security.pam.services.hyprlock = {}` — doğru, kanonik.**
`nixos/modules/security/pam.nix`: `useDefaultRules` ve `unixAuth` varsayılan `true`;
`text` `mkDefault` ile üretiliyor → boş attrset gerçek bir `pam_unix` stack'i veriyor.
Home Manager'ın kendi hyprlock dokümanı da tam olarak bu satırı öneriyor.

**`swapDevices` — değiştirmek gereksiz.**
`nixos/modules/config/swap.nix`: `isDevice = substring 0 5 device == "/dev/"`.
`device = "/dev/disk/by-uuid/…"` + `size = null` → uyarı yok, assert yok, doğru kullanım.
Bu rev'de `fallbackDevice` option'ı henüz yok; liste biçimi + `device` doğru. (Yeni nixpkgs
sürümlerinde `fallbackDevice`'a geçiş olacaksa **ancak o zaman** dokunulmalı.)

**waybar `gamemode` modülü — gerçek.**
`waybar-gamemode(5)`: `format`, `format-alt`, `glyph`, `hide-not-running`, `use-icon`,
`icon-name`, `icon-spacing`, `icon-size`, `tooltip`, `tooltip-format`, `{count}` — config'in
kullandığı her anahtar mevcut, `tooltip-format = "GameMode aktif: {count} oyun"` doğru.

**Güvenlik taraması — temiz.**
- Tüm `.nix` / `.sh` / `qemu` dosyalarında dış ağ yalnızca: `cache.nixos.org`,
  `xddxdd.cachix.org`, `nix-community.cachix.org` (substituter) ve
  `http://localhost:11434/api/generate` (yerel Ollama).
- Zararlı/şüpheli desen taraması (`crypto`, `miner`, `monero`, `token`, `api_key`, `secret`,
  `scp`, `base64 -d`, `eval`, `nc`) → **sıfır eşleşme** (ilgisiz yorumlar hariç).
- `authorizedKeys.keys` **boş** ✓, `PermitRootLogin = "no"` ✓, `PasswordAuthentication = false` ✓,
  `hashedPassword` `.gitignore`'da ✓, 1714-1764 port açığı kaldırılmış ✓.
- `hashedPassword` yokluğu durumunda NixOS'un `die` değil `warn` kullandığı doğrulandı →
  KURULUM §8'deki uyarı ve `mkpasswd --method yescrypt` reçetesi doğru.

**Sözdizimi.**
- `bash -n install.sh` ✓ · `bash -n nixos/hooks/qemu` ✓
- `scripts/extract-embedded-scripts.py` → **7 script** çıkardı (beklenen: 7) ve hepsi
  `bash -n` geçerli ✓
- `vm-xml/win10.xml`: `<hostdev>` sayısı 2 ✓ (extractor'ın beklediği), PCI adresleri
  `hooks/qemu`'daki `GPU_PCI=0000:0b:00.0` / `GPU_AUDIO=0000:0b:00.1` ile tutarlı ✓
- İki PNG de geçerli imza + başlık (bkz. aşağıdaki not)

> **PNG notu:** `assets/wall-.png` = 10806 satır "text" görünüyor çünkü ikili dosya;
> `struct.unpack` ile başlık okundu: `wall-.png` 3840×2160, `kitty-.png` 405 satır (yine ikili).
> İkisi de geçerli PNG. `wall-.png` 3.0 MB — repo'nun %95'i bu tek dosya. README'de
> gereksiz tutuluyor (base64'e gömülebilir ya da LFS'e taşınabilir).

---

## 23. Önerilen düzeltme sırası

**Aynı oturumda, 5 dakika:**
1. `home.nix:446` → `text = $TIME;` · `home.nix:457` → `text = $USER;` *(P1, ekranda görünür)*
2. `home.nix:492-497` yinelenen label bloğunu + `485-491` yinelenen yorumu sil *(P1)*
3. `home.nix:375` → `KeybindManager.cpp:477-488` · `home.nix:477,490` → `hyprland.conf:351` *(P3)*

**İlk `nixos-rebuild`'den önce:**
4. `nix build` ile `low-latency-layer` hash'ini doğrula *(P3 → ama ilk hatadır)*
5. `swtmp`'yi `libvirtd-qemu-ownership` döngüsüne ekle *(P2)*
6. `win10.xml:19` → `edk2-x86_64-vars.fd` *(P2)*
7. `hyprlock` label'larındaki `awk`/`wpctl`/`nmcli`'yi mutlak store yoluna çevir *(P2)*

**Kurulum deneyimini düzelt:**
8. `install.sh:151` → monitör adını `hypr_mon_line` içine göm *(P2)*
9. `install.sh` → `vm-xml` üzerinde çalışma kopyası üzerinde çalış, `skip-worktree` uygulama *(P3)*
10. KURULUM §9b'ye "VM'i TTY'den / `systemd-run` ile başlat" notu *(P2)*
11. `flake.nix` → `impermanence.inputs.home-manager.follows = "home-manager"` *(P2)*

**Sağlamlaştırma (opsiyonel, yararlı):**
12. `exec-once` → tek satır `sh -c '…; …'` *(P1)*
13. hyprlock `cmd[]` label'larında `update:` virgül ayrımını sadeleştir *(gürültü)*
14. `impermanence`'i tamamen kaldır, `home.file` + tmpfiles'e geç *(P3)*
15. power-profiles-daemon ↔ ananicy ↔ gamemode üçlüsüne karar ver *(P3)*
16. `vkbasalt`'ı oyun bazlına çek *(P3)*

**En kritik iki şey (bence):**
- **`hyprland.lua` gölgeleme riskini README'ye yaz.** Bu config'in geleceği buna bağlı ve
  kimse bunu bilmiyor. Tek `nix flake update` + yeni Hyprland = sessiz masaüstü değişimi.
- **`{H:M}` / `{user}`.** Kilit ekranına her baktığında göreceğin, iki saniyelik düzeltme.

---

## 24. Bu analizi nasıl doğruladım

**Yerel çalıştırma (sandbox'ta):**
- 19 metin dosyanın tamamı satır satır okundu (5.684 satır)
- `bash -n` → `install.sh`, `nixos/hooks/qemu`, extractor'ın çıkardığı **7/7** gömülü script
- `scripts/extract-embedded-scripts.py` çalıştırıldı: 7 script üretildi, hepsi geçerli
- `git ls-files` → 21 tracked dosya; `git log`/`git remote` → `97a1665`, upstream
  `github.com/kUmutUK/nixos-hyprland-vfio`
- Python ile: yinelenen blok taraması (hyprlock'ta 1 yinelenen label), flake.lock node/edge
  grafiği, PNG başlık doğrulama, dış-ağ/şüpheli-desen taraması
- `shellcheck` ve `nix` sandbox'ta **yok** (CI'ın kendi kapısı da bu yüzden hâlâ tek doğrulama)

**Birincil kaynak (hepsi sürüm etiketli/ rev'li):**
- `hyprwm/hyprlock` **v0.9.6**: `src/config/ConfigManager.cpp` (kayıt listesi),
  `src/renderer/widgets/Label.cpp`, `src/renderer/widgets/IWidget.cpp` (`formatString`),
  `src/config/ConfigDataValues.hpp`
- `hyprwm/Hyprland` **v0.56.2**: `src/managers/KeybindManager.cpp` (446-476, 477-488),
  `src/config/legacy/DispatcherTranslator.cpp` (475-479, 834),
  `src/config/values/ConfigValues.cpp` (239 anahtar), `src/config/ConfigManager.cpp`,
  `src/config/supplementary/jeremy/Jeremy.cpp`, `src/config/legacy/DefaultConfig.hpp`
- `hyprland-community/pyprland` **3.4.4**: `pyprland/constants.py:41-47`
- `NixOS/nixpkgs` **`7a0f122f5090cf4c2ade2a13a0e229d4e19ba71f`** (kilitli rev):
  `pkgs/by-name/hy/{hyprland,hyprlock,hypridle,hyprpicker,hyprpolkitagent}/package.nix`,
  `pkgs/by-name/py/pyprland/package.nix`,
  `nixos/modules/virtualisation/libvirtd.nix`,
  `nixos/modules/services/display-managers/greetd.nix`,
  `nixos/modules/security/pam.nix`,
  `nixos/modules/config/swap.nix`
- `waybar-gamemode(5)` man sayfası (modül anahtarları)
- Home Manager `programs.hyprlock` doküman sayfası (PAM reçetesi)

**Doğrulayamadıklarım (dürüstlük):**
- `nix eval` / `nixos-rebuild` — sandbox'ta `nix` yok. **Modül sistemi canlı
  değerlendirilmedi.** Özellikle `lsfg-vk-flake` üçüncü taraf modülünün option'ları ve
  `low-latency-layer` derlemesi çalıştırılmadı.
- `shellcheck -S warning` — sandbox'ta yok. CI'daki gate bunu yapıyor.
- Navi 22 reset bug'ı, `rtcwake -m mem` davranışı — donanım/BIOS bağımlı, yalnızca
  gerçek makinede test edilir.
- swtpm dizin sahipliği (bulgu 8) — makine üzerinde `ls -ld /var/lib/libvirt/swtpm` ile
  doğrulanmalı; libvirt sürümüne göre libvirtd'nin zaten doğru sahiplik kurması mümkün.

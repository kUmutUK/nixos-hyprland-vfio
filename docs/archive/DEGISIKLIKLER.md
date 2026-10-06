# Uygulanan Düzeltmeler

Tarih: 2026-10-05 · Baz: commit `af7337f` (belgede geçen `0137b38` ve `602f217` bu repoda yok)

> **DÜZELTME (2026-10-06):** başlıkta `0137b38` geçiyordu. Depo GitHub web
> arayüzünden tek commit olarak yükleniyor; o anki gerçek HEAD `af7337f`.

## ÖNCEKİ RAPORDAKİ P0-1 GERÇEKTEN SAHTE POZİTİFTİ — DÜZELTİLDİ
Raporda "`low_latency_layer` .so'su yüklenemiyor" denmişti. Bu **yanlıştır**
ve uygulanmadı. Gerekçe: `low_latency_layer`'ın `CMakeLists.txt`i, manifesti
`configure_file` ile üretir ve `library_path` alanına
`@CMAKE_INSTALL_FULL_LIBDIR@` yazar. Nix build'inde bu `$out/lib`e yani
**mutlak bir store yoluna** çözülür. Vulkan loader bu yolu `dlopen` ile doğrudan
açar — PATH'te arama yapmaz, `runtimePath`/`LD_LIBRARY_PATH` gerekmez. Store
yolları herkese okunabilirdir ve `environment.etc."...".source` zaten o
derivation'ı GC-root'luyor. `symlinkJoin` sarmalaması gereksiz karmaşıklık
olurdu. (Teyit: `VK_LOADER_DEBUG=layer vulkaninfo | grep -i korthos`)

---

## 1. `nixos/flake.lock` — lock kanonik değildi (asıl kök neden)

`impermanence.inputs` içinde aynı kayıt iki farklı biçimde yazılmıştı:

```json
"nixpkgs":      ["nixpkgs"]      ← follows formu (doğru)
"home-manager":  "home-manager"  ← string formu (yanlış)
```

Nix her değerlendirmede lock'u kanonikleştirdiği için **her `nix flake check`
çalışması dosyayı yeniden yazıyordu**: node adları kayıyordu
(`nixpkgs_3` → `nixpkgs_2`) ve gösterim biçimi değişiyordu.

Düzeltme: lock kanonik hale getirildi. Doğrulandı — artık değerlendirme
lock'a dokunmuyor (`git diff` boş), `nix flake check --no-build` → **all checks
passed!**

> Not: `--accept-flake-config` bayrağını kaldırmak **tek başına yetersizdi**;
> ilk denemede bunu gördüm. Asıl neden lock'un kendisiydi.

## 2. `.github/workflows/check.yml`

- `--accept-flake-config` kaldırıldı (flake'i değerlendirmek için gerekmiyordu;
  `--no-build` yalnızca eval eder, indirme yapmaz).
- **Yeni kapı:** `flake.lock unchanged`. Eval sonrası lock sürüklenirse CI kırılır
  ve fark `git diff` ile basılır. Gelecekte aynı sınıf hata sessizce geçmez.
- `nix flake check` adımına gerekçe açıklaması eklendi.

## 3. `nixos/configuration.nix` — `vm.swappiness` yorumu (1 blok)

Eski yorum iki farklı mekanizmayı karıştırıyordu:

- **Hangi** swap alanının kullanılacağına `priority` karar verir
  (`zramSwap.priority = 100` > disk `priority = 10`) — asıl düzeltmenin gerekçesi bu.
- **`vm.swappiness`** swap'e yazma eğilimini belirler; zram mı disk mi olacağını
  seçmez.

Davranış değişmedi (değer `180` olarak kalıyor), yalnızca gerekçe düzeltildi.

---

## Bilerek dokunulmayanlar

- **P0-1 (`low_latency_layer` .so)** → sahte pozitif, yukarıda gerekçelendirildi.
- `hashedPassword` interaktifliği, `stop_hyprland` tek-kullanıcı varsayımı,
  `fuser` boş-liste koruması, `docs/archive/` temizliği, README haritası →
  doğrulandı ama tek-kullanıcı hedef sistemde pratik etkisi düşük; kapsam
  dışı bırakıldı.

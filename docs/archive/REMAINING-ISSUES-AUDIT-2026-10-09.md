# Kod incelemesi ve düzeltme durumu — 2026-10-09

Bu değerlendirme, gönderilen ZIP'in gerçek içeriğine uygulanmıştır. Liste maddelerinin bir kısmı bu arşiv sürümünde zaten düzeltilmiş veya kasıtlı tasarım tercihi olduğu için aynı şekilde uygulanmamıştır.

## VM'i bloke edebileceği söylenen 6 madde

1. **`vm-xml/win10.xml` VFIO backend:** İki PCI `<hostdev>` bloğunda da `<driver name="vfio"/>` zaten mevcut. Değişiklik gerekmedi. Canlı `virsh dumpxml win10` tanımı, repodaki XML'den farklı olabilir; hostta ayrıca kontrol edilmelidir.
2. **OVMF NVRAM template:** Düzeltildi: `edk2-x86_64-vars.fd` → `edk2-i386-vars.fd`. Bu, paylaşılan C-5 envanterine dayalıdır; hedef sistemde dosya varlığı tekrar doğrulanmalıdır.
3. **`fuser` fail-open:** Düzeltildi. `fuser` çalıştırılabilir değilse masaüstü durdurulmadan işlem kesilir; aygıt düğümleri doğrulanır; `fuser` hata tanılamasıyla dönerse GPU “boş” kabul edilmez. Linux `fuser` non-zero kodu tek başına no-process ve fatal error durumlarını ayırmadığı için stderr de kontrol edilir.
4. **Prepare trap eksikliği:** Düzeltildi. HUP/INT/TERM sinyalleri sırasında rollback denenir. `SIGKILL`, güç kaybı, kernel kilitlenmesi veya başarısız donanım reset'i trap ile kurtarılamaz.
5. **`/nix/persist/home` tmpfiles grubu:** Bu arşivde ilgili `systemd.tmpfiles.rules` satırı yok; 2026-10-09 değişikliğinde kural kasıtlı kaldırılmış ve yorumla açıklanmış. Yanlış `localhost` grubu için değişiklik gerekmedi.
6. **Hook yedeklenmiyor:** Yanlış/eskimiş. `install.sh` yedek listesinde `"$NIXOS_FLAKE_DIR/hooks"` zaten var. Gerçek hata, `cp` başarısızlığının `|| true` ile yutulmasıydı; düzeltildi ve herhangi bir yedek başarısızsa kurulum duruyor.

## Kodda kalan diğer 12 madde

7. **`gitName` / `gitEmail` placeholder:** Kurulumun başlangıç varsayılanı. Installer değer soruyor ve placeholder kalırsa uyarı veriyor; kasıtlı örnek değer, VM başlatma hatası değil.
8. **Duvar kâğıdı video yolu:** Varsayılan örnek yol; kurulumda yol isteniyor, Home Manager servisi dosya yoksa başlamıyor ve bildirim komutu kullanıcıyı uyarıyor. Makineye özel bir varsayılan sorunu, VM bloklayıcısı değil.
9. **`monitorOutput = "DP-3"`:** Genel varsayılan. `install.sh` Hyprland/DRM üzerinden tespit etmeyi ve kullanıcıdan onay/düzeltme almayı deniyor. Başka monitörde kurulum yanıtına göre değer değişmeli.
10. **`home.persistence` yorumu:** Blok yorumda ve yanında bu konfigürasyonda persistence mekanizmasının kapalı olduğunu belirten güncel açıklama var. Bilinçli olarak etkin değil.
11. **impermanence:** Gerçek flake input/module import'u yok; yalnızca kaldırılma gerekçesini anlatan yorum var. Kalan bir import hatası değil.
12. **hyprlock PAM yorumu:** `security.pam.services.hyprlock = { };` ve PAM dosyasına ilişkin açıklama kaynakta mevcut. Statik inceleme tek başına gerçek parola doğrulamasını doğrulayamaz; bu bir VM başlatma engeli olarak teyit edilmedi.
13. **`apply_var` içinde `$` kaçışı:** Fonksiyon `\`, `"` ve `${` dizisini kaçırıyor. Nix string interpolasyonu `${...}` biçimindedir; tek başına `$HOME` Nix tarafından shell değişkeni gibi genişletilmez. İddia bu haliyle hatalı.
14. **`apply_var` hatasında çıkış:** Installer `set -euo pipefail` kullanıyor; başarısız değişken uygulamasında durması, eksik/karışık yapılandırmayı kurmaya devam etmemek açısından fail-fast tercihi. `warn` mesajı yazıldıktan sonra çıkış kodu 1 olur.
15. **`sed -i 0` eşleşmesi:** Bu arşivde iddia edilen `sed -i 0` örüntüsü bulunmadı. Installer'daki GPU XML senkronizasyonu Python ile yapılıyor.
16. **hardware-configuration yedeği iki kez:** Liste iki farklı yolu yedekliyor: `/etc/nixos/hardware-configuration.nix` ve `/etc/nixos/nixos/hardware-configuration.nix`. Hedef adları kaynak yolundan türetildiği için aynı isimle birbirini ezmiyor; makine yapılandırmalarını korumak için ikisi de bırakıldı.
17. **Executable bit:** Düzeltildi: `install.sh`, `nixos/hooks/qemu`, `scripts/extract-embedded-scripts.py` çalıştırılabilir olarak işaretlendi.
18. **`extract-embedded-scripts.py` ve `vfioHook`:** Extractor hâlâ `home.nix` betiklerine odaklanıyor; ancak bu boşluğu daha güvenilir biçimde kapatmak için CI'a `configuration.nix` tarafından üretilen `virtualisation.libvirtd.hooks.qemu.vfio` dosyasını build edip ShellCheck ile denetleyen adım eklendi. Asıl `nixos/hooks/qemu` kaynağı da ayrı taranmaya devam ediyor.

## Kozmetik 5 madde

19. **`docs/archive/README.md` içindeki `assets/example.conf`:** Bu sürümde arşiv README'si ilgili olmayan eski kaynakların bulunmadığını belirtiyor; etkin metindeki yanlış atıf CHANGELOG'da önceki düzeltme olarak kayıtlı. Yeniden değiştirilmedi.
20. **CHANGELOG [1.3.2] atfı:** CHANGELOG geçmiş sürüm kayıtlarıdır; o sürümde yapılan düzeltmeyi tarif eden kayıtları bugünkü dosyalarla aynılaştırmak tarihçeyi bozardı.
21. **`services.hypridle` girintisi:** Düzeltilerek Nix biçimlendirmesi okunabilir hâle getirildi; değerler aynı.
22. **`pcie_aspm=off` güç tasarrufu açıklaması:** README'de düzeltildi; ASPM kapatma/firmware davranışı artık güç tasarrufu garantisi olarak ifade edilmiyor.
23. **`7a0f122` commit kimliği referansları:** Görülen eşleşmeler CHANGELOG'daki tarihsel sürüm anlatımlarında. Bunları güncel `flake.lock` rev'iyle topluca değiştirmek tarihsel kayıtları yanlış yapar. Etkin flake kilidindeki nixpkgs rev'i `151fa4e8ddfdd8dd25d945ad94ed54a13de9f6e4`.

## Bu pakette uygulanan değişiklikler

- NVRAM template yolu düzeltildi.
- VFIO hook'unda `fuser` kontrolü fail-closed hale getirildi ve prepare sinyalleri için rollback trap'i eklendi.
- Installer yedekleme hatalarını gizlemek yerine kurulumdan önce duracak şekilde düzeltildi.
- Hypridle girintisi ve ASPM açıklaması düzeltildi.
- Üç betik dosyasının yürütme bitleri düzeltildi.
- CI, Nix tarafından üretilen VFIO hook sarmalayıcısını ayrıca derleyip ShellCheck ile denetleyecek şekilde genişletildi.

## Doğrulama sınırı

Bash sözdizimi, XML well-formedness, extractor regresyonu ve dosya izinleri yerel olarak kontrol edilebilir. Nix değerlendirmesi/build'i ve `virsh start win10` / gerçek GPU passthrough denemesi hedef NixOS makinede yapılmalıdır. Bu rapor VM'nin çalıştığını iddia etmez.

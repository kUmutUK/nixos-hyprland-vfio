# NixOS + Hyprland + VFIO — doğrulama ve düzeltme kaydı

**Tarih:** 2026-10-12  
**Kapsam:** Sağlanan `nixos-hyprland-vfio(3).zip` içeriği ve bu paketteki `install.sh`  
**Canlı sistem / VM:** Bu çalışma ortamından erişilemedi; hiçbir kurulum veya VM komutu çalıştırılmadı.

## Uygulanan düzeltmeler

### N1 — `hardware-configuration.nix` sessizce ezilmesin

- `/etc/nixos/hardware-configuration.nix` ile flake hedefindeki dosya farklıysa `diff -u` gösterilir.
- Kullanıcı açıkça `yes` yazmadıkça mevcut flake dosyasının üzerine yazılmaz; boş yanıt varsayılan olarak hayırdır.
- Dosyalar aynıysa gereksiz kopyalama yapılmaz.
- Kullanıcı mevcut flake dosyasını korursa, UUID ve mount ayarlarını rebuild öncesinde kontrol etmesi ayrıca uyarılır.
- Hedef yol normal bir dosya değilse betik durur.

### N2 — VM XML dosyasını atomik yaz

- XML önce hedefle aynı dizinde `tempfile.mkstemp()` ile oluşturulan geçici dosyaya yazılır.
- Yazma, `flush()` ve `fsync()` tamamlandıktan sonra `os.replace()` ile hedefe atomik olarak taşınır.
- Hata durumunda geçici dosya temizlenmeye çalışılır; önceki hedefin yarım yazılmış bir XML ile ezilmesi engellenir.
- Var olan dosyanın izinleri ve sahipliği korunur; ilk dosya için olağan `0644` modu kullanılır.
- Mevcut XML için önceki yedekleme davranışı korunur.

### N3 — Eski yedekleri temizlerken ad biçimini doğrula

- Yalnızca adı `\.nixos-config-backup-[0-9]{8}-[0-9]{6}` kalıbına tam uyan dizinler otomatik temizleme listesine alınır.
- Kalıp, sıralamadan önce doğrulanır; benzer isimli manuel klasörler yedek sayısına dahil edilmez ve otomatik silinmez.
- Geçerli isimli yedeklerden en yeni beşi tutulur; eski olanlar silinir.

## Arşiv içeriğiyle teyit edilen diğer maddeler

### H11 — “üç uncommitted değişiklik”

Sağlanan ZIP'in içindeki Git çalışma ağacı başlangıçta temizdi (`git status --short` çıktı üretmedi). `README.md`, `nixos/configuration.nix` ve `vm-xml/win10.xml` için başlangıçta bekleyen değişiklik görülmedi. Bu düzeltme paketinde değişen tek mevcut proje dosyası `install.sh`'tir. Depodaki Git geçmişi tek, sığ (shallow) commit içerdiğinden daha eski bir çalışma ağacının durumu hakkında çıkarım yapılmadı.

### N4 — `assets/` klasörü

Kullanıcı `assets/` klasörünü bilerek sildiğini doğruladı. Bu yüzden PNG’lerin bulunmaması paketleme hatası değil. Aktif yapılandırmada bu klasöre referans bulunmadı; güncel README’de eski klasör girdisi kaldırıldı. CHANGELOG ve `docs/archive/` içindeki tarihsel atıflar geçmiş bağlamında bırakıldı.

## Canlı sistemde doğrulanmayı bekleyen maddeler

- **A3 — swtpm sahipliği:** `configuration.nix` içinde dizin mevcut değilse sahiplik düzeltmesini atlayan `if [ -d "$d" ]` kontrolü var. Gerçek makinedeki durum şu komutla kontrol edilmeli: `stat -c '%A %U:%G' /var/lib/libvirt/swtpm`. Burada hedef sistemin dizinini okuyamadığım için sonuç varsayılmadı.
- **C14 — `system.stateVersion`:** depoda `system.stateVersion = "26.05"` ve `home.stateVersion = "26.05"` var. Tek sığ commit, hedef sistemin ilk kurulum sürümünü kanıtlamıyor. Bu nedenle değiştirilmedi.
- **C19 — OVMF:** XML şunları bekliyor: `/run/libvirt/nix-ovmf/edk2-x86_64-code.fd` ve `/run/libvirt/nix-ovmf/edk2-i386-vars.fd`; NVRAM hedefi `/var/lib/libvirt/qemu/nvram/win10_VARS.fd`. Gerçek `/run/libvirt/nix-ovmf/` dosyaları ve `virsh dumpxml win10` canlı host üzerinde kontrol edilmeli. Sadece isim varsayımına dayanarak XML değiştirilmedi.
- **H10:** `scripts/prepare-vm-diagnostic.py` depoda bulunuyor. Tanılama XML'ini üretmek ve `virsh define` ile etkinleştirmek otomatik kurulum adımı değil; VM testi sırasında elle, mevcut domain XML'inin geri yükleneceği planla uygulanmalı.
- **C17:** `boot.initrd.availableKernelModules = lib.mkAfter [ "amdgpu" ];` bırakıldı. Bu yapılandırmada LUKS initrd'de açılıyor; şifre ekranının gerçek konsol/ekran davranışı canlı test edilmeden modülün kaldırılması güvenli sayılmaz.

## Yapılan kontroller

Başarılı:

- `bash -n install.sh`
- `git diff --check`
- `install.sh` içindeki iki gömülü Python bloğunun sözdizimi derlemesi
- `vm-xml/win10.xml` XML ayrıştırması
- `nixos/flake.lock` JSON ayrıştırması
- **N1** izole test: `no` var olan hedefi koruyor; `yes` fark gösterildikten sonra hedefi değiştiriyor.
- **N2** izole test: yeni XML üretimi, atomik değiştirme, dosya modu ve mevcut UUID/MAC kimliğinin korunması, geçici dosyanın temizlenmesi.
- **N3** izole test: biçimi doğru olan yedi yedekten en eski ikisi siliniyor; biçimi yanlış olan üç benzer adlı dizin korunuyor.
- Başlangıç arşivinde `git status --short` temizdi; bu düzeltmeden sonra yalnızca `install.sh` değişti.

Bu ortamda `nix` ve `shellcheck` bulunmadığından `nix flake check --no-build` ve ShellCheck çalıştırılmadı. `nixos-rebuild dry-activate`, `virsh define/start`, üç döngülü VM testi, Navi 22 reset testi, `rtcwake -m mem`, kernel LTO süresi ve Ollama ROCm performans testi yapılmadı.

## Sonuç

N1–N3, `install.sh` üzerinde uygulandı ve izole testlerle doğrulandı. A3, C14, C19 ve C17 hedef makineye bağlı kaldı. Bu paket, NixOS rebuild veya gerçek GPU passthrough başarısı garantisi değildir.

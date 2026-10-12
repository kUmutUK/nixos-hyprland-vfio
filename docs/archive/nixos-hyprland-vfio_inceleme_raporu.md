# NixOS + Hyprland + VFIO deposu — ayrıntılı statik inceleme

**İncelenen arşiv:** `nixos-hyprland-vfio(3).zip`  
**İnceleme tarihi:** 12 Ekim 2026  
**Yöntem:** Kaynak kod, Nix yapılandırmaları, kurulum dokümanları, libvirt XML ve dosyalar arası bağımlılıkların statik incelemesi. Kurulum betiği, QEMU hook'u ve diğer proje kodları çalıştırılmadı; gerçek makinede NixOS rebuild veya GPU passthrough testi yapılmadı.

## 1. Yönetici özeti

Bu depo, tek AMD ekran kartını Linux host ile Windows 10 sanal makinesi arasında devreden, oyun odaklı bir NixOS 26.05/unstable yapılandırmasıdır. Kapsamı masaüstü görünümünden çok daha geniştir: disk şifreleme ve Btrfs alt hacimleri, Snapper, Hyprland/Home Manager, oyun gecikmesi ayarları, özel CachyOS BORE-LTO kernel'i, libvirt/QEMU, OVMF, swtpm ve GPU reset/kurtarma akışı birbirine bağlıdır.

Arşivde **24 Git tarafından izlenen dosya** bulunuyor. ZIP içinde ayrıca `.git` nesneleri ve standart Git hook örnekleri var. Depodaki en yeni changelog girdisi 1.3.8 (2026-10-12). Bu sürümün kendi notu, Nix değerlendirme/derleme, ShellCheck ve gerçek GPU/VM passthrough testlerinin yapılmadığını açıkça belirtiyor.

### Genel değerlendirme

- **Olumlu:** Kurulum ve VM akışı kapsamlı biçimde belgelenmiş. PCI adresleri doğrulanıyor; kurulum öncesi yapılandırma yedeği alınıyor; VM XML şablonu kaynağında değiştirilmeden dağıtım kopyası üretiliyor; VFIO hazırlığı başarısız olursa geri alma deneniyor; tehlikeli uyku/rescan kurtarma yolu varsayılan olarak kapalı.
- **Olumlu:** Eski analizlerde görülen bazı sorunların giderildiği ve geri çekilen iddiaların açıkça kayıt altına alındığı anlaşılabiliyor. Arşivdeki eski bulgular doğrudan güncel kusur listesi olarak kullanılmamalı.
- **Kritik sınırlama:** Statik sözdizimi kontrolü, Nix option'larının doğru olduğunu veya hedef donanımda VM açılacağını kanıtlamıyor. Çalışma zamanı testi şart.
- **En önemli operasyonel risk:** Tek GPU tasarımı, VM hazırlanırken grafik oturumunu kapatıyor; VM sonlandıktan sonra GPU'nun host sürücüsüne yeniden bağlanması donanım reset davranışına bağlı. RX 6700 XT/Navi 2x üzerinde ikinci başlatma, zorla kapatma ve host'a geri dönüş özellikle denenmeli.

## 2. Gerçekleştirilen kontroller ve kapsam dışı kalanlar

### Gerçekleştirilen statik kontroller

| Kontrol | Sonuç | Bunun anlamı |
|---|---|---|
| ZIP içerik envanteri ve yol kontrolü | Tamamlandı | Arşiv yolu güvenli biçimde açıldı; dosya listesi çıkarıldı. |
| Git dosya listesi ve HEAD | Tamamlandı | 24 takip edilen dosya; çalışma ağacı temiz; HEAD `a42a140` (`Add files via upload`). |
| `bash -n install.sh nixos/hooks/qemu` | Başarılı | Bu iki Bash dosyasının temel sözdizimi ayrıştırılabiliyor; mantıksal doğruluğu kanıtlamaz. |
| İki Python dosyasının AST ayrıştırması | Başarılı | Python kaynaklarının sözdizimi geçerli. |
| `vm-xml/win10.xml` XML doğrulaması | Başarılı | XML iyi biçimlenmiş. Libvirt'in hedef makinede her aygıtı kabul edeceğini kanıtlamaz. |
| `nixos/flake.lock` JSON ayrıştırması | Başarılı | Kilit dosyası geçerli JSON. Nix'in tüm girdi ve option'ları değerlendirdiğini kanıtlamaz. |
| Dosyalar arası referans ve doküman karşılaştırması | Tamamlandı | Donanım adresleri, disk/ISO/OVMF yolları, hook ve servis davranışları karşılaştırıldı. |

### Yapılmayan kontroller

Bu inceleme ortamında `nix`, `nix-instantiate` ve `shellcheck` bulunmadığından `nix flake check`, tam Nix değerlendirmesi, derleme ve ShellCheck çalıştırılmadı. `nixos-rebuild dry-activate`, gerçek libvirt başlatma/kapatma, VM içi Windows kurulumu, swtpm/OVMF doğrulaması, suspend/rescan kurtarması ve fiziksel GPU reset testi de yapılmadı. CI dosyasının bulunması, bu ZIP için CI'ın çalıştığını veya geçtiğini göstermez.

## 3. Önceliklendirilmiş bulgular

### P1 — GPU host'a geri dönmezse siyah ekran/yeniden başlatma gerekebilir

**İlgili dosyalar:** `nixos/hooks/qemu`, `nixos/configuration.nix`, `README.md`, `KURULUM.md`

Hook, `prepare` aşamasında masaüstünü durduruyor, metin konsollarını/EFI framebuffer'ı ayırıyor ve GPU ile ses fonksiyonunu `vfio-pci` sürücüsüne bağlıyor. VM kapanışında host sürücülerini geri bağlamayı ve Hyprland/greetd'i başlatmayı deniyor. Bununla birlikte kaynak, Navi 2x/RX 6000 kartlarının reset davranışında sorun çıkabileceğini açıkça kabul ediyor. `remove + rtcwake + rescan` kurtarma yolu otomatik etkin değil; bilerek opt-in bırakılmış.

**Etki:** VM ikinci kez açıldığında veya zorla kapatıldığında GPU resetlenmezse host görüntüsü geri gelmeyebilir. Kodun geri alma mantığı yararlı ama `SIGKILL`, güç kaybı, kernel kilidi ya da donanımın kurtarılamaması gibi durumları gideremez.

**Öneri:** Günlük kullanımdan önce gerçek kartta şu senaryoları sınayın: VM başlat → Windows'u normal kapat → host görüntüsünün geri geldiğini doğrula → ikinci kez başlat; ayrıca Windows'u zorla kapatma/VM çökmesi senaryosunu da deneyin. Kurtarma fallback'ini sadece BIOS/RTC davranışı ve acil kurtarma yöntemi anlaşıldıktan sonra etkinleştirin. Test başarılı değilse bu tasarımı üretim/günlük iş akışına almamak daha güvenli.

### P1 — VM başlatma, host kullanıcı ve grafik oturumlarını sonlandırabilir

**İlgili dosyalar:** `nixos/hooks/qemu`, `README.md`, `KURULUM.md`

Hook `loginctl terminate-user localhost` ve `loginctl terminate-seat seat0` çağrılarını kullanıyor. Bu tek GPU tasarımında host grafik ortamını GPU devri için kapatmayı amaçlıyor; ancak yalnızca Hyprland penceresini kapatmakla sınırlı değil. İlgili kullanıcıya ait terminal/oturumlar da kapanabilir. Bu nedenle dokümantasyonda `virsh start win10` komutunun normal terminal yerine `systemd-run` ile ayrık bir sistem hizmeti olarak çalıştırılması söyleniyor.

**Etki:** Yanlış başlatma yöntemi açık terminalin ve masaüstü oturumunun kapanmasına neden olabilir. Bu davranış beklenen tasarım özelliği olsa da kullanıcı deneyimi ve kurtarma açısından yüksek etkili.

**Öneri:** Belgelenen detached `systemd-run` komutunu koruyun; mümkünse VM başlatma için kontrollü bir systemd unit/wrapper sağlayıp normal shell'den doğrudan başlatmayı engelleyin. Sistemin tek kullanıcı/tek GPU hedefi olduğuna ilişkin uyarıyı görünür tutun.

### P1 — VM şablonu makineye özgü PCI, disk, ISO ve OVMF yolları varsayıyor

**İlgili dosyalar:** `vm-xml/win10.xml`, `install.sh`, `nixos/hardware-configuration.nix`, `README.md`, `KURULUM.md`

VM tanımı `0000:0b:00.0` ve `0000:0b:00.1` PCI adresleri, `/var/lib/libvirt/images/win10new.qcow2`, iki özel ISO adı, `/run/libvirt/nix-ovmf/...` OVMF yolları ve sabit bir QEMU makine türü (`pc-q35-10.1`) gibi varsayımlar içeriyor. `install.sh`, hook'taki GPU adreslerini ve dağıtılan XML'in ilk iki PCI hostdev girdisini senkronlamaya çalışıyor. Betik çalıştırılmazsa bu otomatik eşitleme yapılmaz.

**Etki:** Yanlış PCI adresi VM başlatmayı engelleyebilir veya yanlış donanıma işaret edebilir. Eksik qcow2/ISO/OVMF dosyaları VM'nin açılmamasına neden olur. Kaynak XML tek başına taşınabilir bir VM tanımı değildir.

**Öneri:** VM'yi tanımlamadan önce şunları doğrulayın: `lspci -nn` ile GPU ve ses fonksiyonu, XML'deki iki `<hostdev>` adresi ile hook değişkenleri aynı mı, qcow2 ve iki ISO dosyası var mı, OVMF kod ve NVRAM şablon yolları gerçek host'ta mevcut mu? Depodaki `hardware-configuration.nix` UUID'lerini başka makinede kullanmayın.

### P2 — `hardware-configuration.nix` yeniden kurulumda üst dizindeki kopyayla ezilebilir

**İlgili dosya:** `install.sh` (özellikle yaklaşık 280. satır civarı)

Kurulum betiği `/etc/nixos/hardware-configuration.nix` mevcutsa bunu doğrudan `/etc/nixos/nixos/hardware-configuration.nix` üzerine kopyalıyor. Standart bir kurulumda bu davranış kullanıcının gerçek donanım dosyasını flake altına taşımak açısından mantıklı. Ancak flake altındaki dosya daha önce özel mount, Btrfs alt hacmi veya cihaz ayarı için özelleştirildiyse ve üst dizindeki kopya farklı/eski kaldıysa, bu özelleştirme sessizce ezilebilir.

**Etki:** Sonraki rebuild yanlış UUID veya dosya sistemi tanımlarıyla başarısız olabilir; daha ağır durumda açılış acil kipte kalabilir.

**Öneri:** Üst dosya mevcutken hedef dosyanın da var olup olmadığını kontrol edin. Hedef varsa otomatik üzerine yazmak yerine diff gösterip açık onay isteyin; her iki dosya için de yedek alınması iyi ama kullanıcı onayı/karşılaştırması daha güvenli.

### P2 — `system.stateVersion` ve `home.stateVersion` gerçek kurulum geçmişine göre doğrulanmalı

**İlgili dosyalar:** `nixos/configuration.nix`, `nixos/home.nix`

İki dosya da `26.05` değerini kullanıyor. Bu değer yalnızca hedef sistemdeki en güncel sürümü belirtmek için gelişigüzel ayarlanacak bir ayar değil; kurulmuş sistemin varsayılan/uyumluluk davranışlarını koruması için ilk kurulum sürümüyle eşleşmesi gerekir.

**Etki:** Daha eski bir NixOS kurulumu bu yapılandırmaya taşınıyorsa stateVersion'ın uygunsuz değiştirilmesi bazı varsayılanların beklenmedik değişmesine neden olabilir. Bu arşivde önceki denetim `C14` konusunu hedef sistemde çözülmesi gereken canlı kontrol olarak bırakmış.

**Öneri:** Yeni kurulumda dokümante edilen 26.05 hedefiyle tutarlı olun; mevcut sistemi taşırken gerçek ilk kurulum sürümünü öğrenin ve `system.stateVersion` ile `home.stateVersion` değerlerini gerekçesiz değiştirmeyin.

### P2 — Açılışta swtpm sahipliği ve OVMF NVRAM dosyası hedef makinede doğrulanmalı

**İlgili dosyalar:** `nixos/configuration.nix`, `vm-xml/win10.xml`

Yapılandırma `qemu.runAsRoot = false` kullanıyor. Bu nedenle VM diski, NVRAM ve swtpm state dosyalarının `qemu-libvirtd` hesabı tarafından okunabilmesi gerekir. Açılışta çalışan `libvirtd-qemu-ownership` oneshot hizmeti `/var/lib/libvirt/images`, `/var/lib/libvirt/qemu` ve `/var/lib/libvirt/swtpm` ağaçlarını en fazla iki seviye derinliğe kadar `chown` etmeye çalışıyor; hataları ve eksik yolları bilerek yutuyor.

**Etki:** Dosya yolu beklenenden farklıysa, swtpm klasörü henüz oluşmadıysa veya gerekli dosya daha derindeyse sahiplik düzeltmesi tamamlanmayabilir. Aynı şekilde XML'deki `edk2-i386-vars.fd` şablonunun gerçek NixOS runtime envanterinde bulunması gerekir. Arşivin birleştirilmiş denetim belgesi bu konuları `A3` ve `C19` olarak canlı test bekleyen maddeler arasında bırakıyor.

**Öneri:** Hedef sistem yeniden başlatıldıktan sonra unit loglarını, `/var/lib/libvirt/swtpm`, `/var/lib/libvirt/qemu/nvram` izinlerini ve XML'deki loader/template yollarının varlığını kontrol edin. Dosya sahipliği servisinin tüm VM depolama alanını geniş kapsamlı değiştirdiğini de not edin; mümkün olduğunda sahiplik değişikliklerini gerekli dosyalarla sınırlayın.

### P2 — Açık swap, LUKS şifrelemesinin koruma kapsamı dışında

**İlgili dosya:** `nixos/hardware-configuration.nix`

Root ve Btrfs alt hacimleri LUKS2 arkasındayken disk swap bölümü doğrudan UUID ile tanımlanmış ve kendisi şifrelenmemiş. `zram` swap önceliği disk swap'ten yüksek; bu disk swap'in hiç kullanılmayacağı garantisi vermez.

**Etki:** Sistem belleğinin bir kısmı disk swap'e yazılırsa, bu veriler LUKS root biriminin sağladığı bekleme hâlindeki şifreleme korumasının dışında kalabilir.

**Öneri:** Fiziksel diskteki veri kalıntıları tehdit modelinizde önemliyse şifreli swap veya yalnızca uygun boyutlandırılmış zram gibi bir tasarımı değerlendirin. Mevcut tasarım belgelerde açıkça not edilmiş; burada gizli bir davranış değil, güvenlik tercihidir.

### P2 — Kernel ayarları tanı/arıza giderme yeteneklerini ve güç tüketimini etkiliyor

**İlgili dosyalar:** `nixos/configuration.nix`, `README.md`, `KURULUM.md`

Kernel parametreleri arasında `nowatchdog`, `nmi_watchdog=0`, `usbcore.autosuspend=-1`, `kvm.ignore_msrs=1`, `iommu=pt`, `amd_iommu=on` ve AMD performans maskesi var. Kod içi açıklamalar bazı maliyetleri yerinde belirtiyor: watchdog kapatma teşhis imkânını düşürür, USB autosuspend'i kapatma güç tüketimini artırabilir, `kvm.ignore_msrs=1` bazı hataları gizleyebilir. `pcie_aspm=off` hakkında da belge özel uyarı içeriyor.

**Öneri:** Her parametreyi “gaming için olduğu için zararsız” kabul etmeyin. Bir sorunda teşhis için hangi ayarların test amacıyla kapatılacağını önceden belgeleyin. Güç/ısı/kararlılık izlemesini gerçek sistemde yapın.

### P3 — `README.md` içindeki `assets/` atfı (düzeltildi)

**İlgili dosya:** `README.md`

Kullanıcı `assets/` klasörünü bilerek sildiğini doğruladı. Etkin Nix/Hyprland yapılandırmasında bu klasöre çalışan bir dosya yolu referansı bulunmuyor; eski `CHANGELOG.md` ve `docs/archive/` atıfları tarihsel bağlamda kalıyor. README'deki güncel klasör açıklaması ve depo ağacından `assets/` girdisi çıkarıldı.

**Durum:** Dokümantasyon güncellendi; çalışma zamanı için ayrıca bir değişiklik gerekmedi.

### P3 — Betik çıkarıcı, güncel `home.nix` biçimine özel ve kırılgan

**İlgili dosya:** `scripts/extract-embedded-scripts.py`

Bu araç `home.nix` içindeki belirli marker satırlarını ve Nix indented-string sınırlarını regex/arama ile çözüyor. Nix kaçışlarını dönüştürürken çıkarılan içerikteki `''` dizilerini de genel olarak siliyor. Bugünkü yedi gömülü Bash betiği için CI sözleşmesine göre yazılmış; keyfi Nix string'lerini doğru şekilde ayrıştıran genel amaçlı bir Nix parser değil.

**Etki:** `home.nix` düzeni değişince bir betik çıkarılmayabilir veya çıkarılmış içerik gerçek kaynakla bire bir aynı olmayabilir. CI tam yedi betik beklediğinden bazı kaçırmaları yakalar ama içerik dönüşümünün semantik doğruluğunu tek başına kanıtlamaz.

**Öneri:** Gömülü betiklerin biçimi değiştiğinde çıkarılan dosyaları gerçek kaynakla karşılaştırın; mümkünse Bash betiklerini ayrı dosyalara taşıyıp Home Manager'dan bu dosyalara referans verin.

## 4. Dosya bazında inceleme

### Proje kökü ve dokümantasyon

#### `README.md`

Projenin amacı, hedef donanımı, mevcut sisteme kurulum ve sıfırdan kurulum, VM başlatma ve geri alma akışı, tuş kısayolları, bilinen sınırlar ve dosya haritasını anlatıyor. Özellikle tek GPU nedeniyle host grafik oturumunun kapanacağı, RX 6000 reset davranışının garanti olmadığı, USB klavye/farenin otomatik aktarılmadığı, açık swap ve donanıma özgü XML yolları gibi önemli sınırlar belgelenmiş. Tanılama XML'inin aynı `win10` domain adını kullandığı ve bu yüzden mevcut domain tanımını geçici olarak değiştirdiği de açıkça söyleniyor. Başlangıçtaki README, arşivde bulunmayan `assets/` klasörünü listeliyordu; kullanıcı klasörü bilerek sildiğini belirtti ve aşağıdaki takip düzeltmesinde README bu durumla eşitlendi.

#### `KURULUM.md`

UEFI, disk bölümleme, LUKS2, Btrfs alt hacimleri, `/home/.snapshots` hazırlığı, donanım yapılandırması üretme, şifre hash dosyasını oluşturma, ilk kurulum, VM diski tanımlama ve ilk reboot sonrası VM hazırlığını adım adım anlatıyor. `sgdisk -Z` bölüm tablosunu sileceğinden seçilen diskin doğruluğu kritik. Swap'in şifresiz olduğunu ve SSH parola kimlik doğrulamasının kapalı/authorized key listesinin boş olduğunu anlatması iyi. Kurulum sıfırdan yapılırken şablondaki donanım UUID'lerinin yerine yeni makinenin ürettiği değerlerin taşınması şart. `mkdir -p /mnt/nix/persist/home` komutu ilgili bölümde artık gerekli olmadığı açıklanmasına rağmen tutulmuş; çoğunlukla zararsız ama rehber temizliği için kaldırılabilir.

#### `CHANGELOG.md`

1.3.8 girdisi son değişiklikleri ve bu arşivde yapılmayan doğrulamaları açıkça belirtiyor. Eski girdiler geçmiş kararları ve bazı hataların nasıl giderildiğini izlemek için faydalı, ancak her tarihsel doğrulama şimdiki ZIP için çalışma zamanı kanıtı değildir. En üstteki not, Nix evaluate/build, ShellCheck ve fiziksel passthrough yapılmadığını netleştiriyor.

#### `CONTRIBUTING.md`

Katkı/branch düzeni, biçimlendirme ve doğrulama komutları hakkında temel yönergeleri içeriyor. Doğrulama beklentisi CI ile genel olarak uyumlu; fakat komutların başarıyla çalıştığı bu incelemede yeniden test edilmedi.

#### `LICENSE`

MIT lisansı içeriyor. Kaynak ağacından kaynaklanan belirgin bir tutarsızlık görülmedi.

#### `.gitignore`

Nix `result` bağlantıları, geçici çıktılar, Python cache dosyaları, VM diski/ISO'lar ve `hashedPassword` gibi hassas veya büyük dosyaları dışlamaya yönelik kurallar içeriyor. Parola hash'inin Git'e girmemesi doğru. Yine de ignore kuralı, dosyanın başka bir yerde yedeğe alınmaması ya da yanlış izinlerle bırakılmaması gereğini ortadan kaldırmaz.

#### `.github/workflows/check.yml`

CI; `install.sh` ve QEMU hook'u için ShellCheck, yapılandırmadan üretilen hook wrapper'ı için derleme/ShellCheck, `home.nix` içinden çıkarılan tam yedi betiğin taranması, `nix flake check --no-build` ve sonunda `flake.lock` değişmedi denetimi kuruyor. `statix`/`deadnix` adımları bilerek uyarı üretip pipeline'ı bloklamıyor. `--no-build` adımı NixOS sistemini derlemez; option değerlendirmesi yapar. Bu incelemede workflow tetiklenmediğinden CI sonucu hakkında hüküm verilemez.

### Tarihsel denetim dosyaları (`docs/archive/`)

#### `docs/archive/README.md`

Arşiv raporlarının eski ZIP/revizyonların anlık görüntüleri olduğunu, mevcut kusur kontrol listesi olarak doğrudan uygulanmaması gerektiğini belirtiyor. Doğru kullanım talimatı.

#### `docs/archive/HISTORICAL-AUDITS.md`

Önceki bulguların düzeltme/geri çekme kayıtlarını konsolide ediyor. Özellikle şu dört konuyu canlı hedef üzerinde çözülmesi gerekenler olarak belirtiyor: `A3` swtpm dizini/sahipliği; `C14` yüklü `system.stateVersion` uyumluluğu; `C17` initrd `amdgpu` gerekliliği; `C19` OVMF NVRAM şablonu varlığı. Bu raporlar bu incelemede de uygun sınırlar olarak kabul edildi; fiziksel makine olmadan kesin çözümlenemezler.

#### `docs/archive/ANALIZ-2026-10-05-ZIP3-SUPERSEDED.md`

5 Ekim tarihli önceki ZIP'e ait tarihsel inceleme. Dosya adındaki `SUPERSEDED` etiketi gereği açık maddeleri güncel kodda tekrar kontrol etmeden bug kabul etmeyin.

#### `docs/archive/nixos-hyprland-vfio-analiz-v2-SUPERSEDED.md`

Daha eski ZIP/revizyona ait tarihsel rapor; aynı `SUPERSEDED` kuralı geçerli.

#### `docs/archive/NIXOS-HYPRLAND-VFIO-ANALIZ.md`

Önceki analiz/validasyon notları. Mevcut kaynakta düzeltme yapılmış olabileceğinden buradaki adımları doğrudan uygulamak yerine güncel `README.md`, `KURULUM.md` ve kaynakla karşılaştırın.

#### `docs/archive/DEGISIKLIKLER.md`

5 Ekim dönemi etrafındaki değişiklik ve karar günlüğü. Karar gerekçesini izlemek için faydalı, güncel doğrulama raporu değil.

#### `docs/archive/REMAINING-ISSUES-AUDIT-2026-10-09.md`

9 Ekim snapshot'ındaki açık hususları içeriyor. 12 Ekim `HISTORICAL-AUDITS.md` dosyası sonradan bazı iddiaları geri çektiği için bu dosya tek başına güncel kusur listesi olarak kullanılmamalı.

### Kurulum ve NixOS çekirdeği

#### `install.sh`

Girdi doğrulaması, makine/PCI algılama, IOMMU grup kontrolü, kullanıcı ayarlarının sorulması, yedek alma, konfigürasyon kopyalama, hook ve XML senkronizasyonu işlerini yapıyor. `set -euo pipefail` kullanması, root olarak çalışmayı reddetmesi, PCI adresini regex ve sysfs üzerinden doğrulaması ve yedek alma başarısızsa kopyalama öncesi durması olumlu. XML şablonunu kaynak depoda değiştirmemesi ve dağıtılan XML'de UUID/MAC kimliğini koruması da iyi.

Dikkat gereken noktalar:

1. Üst dizinde `hardware-configuration.nix` varsa flake içindeki hedef dosyaya koşulsuz kopyalar; hedefteki özelleştirmeler için önce karşılaştırma/uyarı eklenmeli.
2. VM XML'ini yazma işlemi önce yedek alma mantığı içerse de hedef dosyaya yazım atomik değil. Düşük olasılıklı I/O hatalarında hedef yarım yazılabilir; geçici dosya + `os.replace` daha dayanıklı olur.
3. Betik tam bir işlem günlüğü/otomatik rollback sunmuyor: bazı dosyalar kopyalandıktan sonra sonraki adım hata verirse kullanıcı yedekten elle geri dönmek zorunda kalabilir.
4. Yalnızca ilk iki PCI `<hostdev>` adresi otomatik güncelleniyor. XML'de iki cihazdan fazla hostdev bulunursa uyarı veriliyor; kalan cihazlar elle düzenlenmeli.
5. Yedekleri saklama politikası `.nixos-config-backup-*` ad alanındaki eski klasörleri silebilir. Aynı adlandırma kalıbını kullanıcı kendi klasörleri için de kullanıyorsa bu klasörler de silme kapsamına girebilir; koruma yalnızca tam prefix'e dayanıyor.

#### `nixos/flake.nix`

`nixos-unstable`, CachyOS kernel overlay'i, Home Manager ve `lsfg-vk` flake girdilerini kullanıyor; sistem `x86_64-linux` ile sınırlı. CachyOS BORE-LTO kernel paketi seçiliyor. `nixConfig` altında ek binary cache'ler ve public key'ler bildiriliyor; `--accept-flake-config` ile kabul edilen bir flake bu nedenle güven sınırını da etkiler. Bu cache'lere güvenip güvenmediğinizi bilinçli değerlendirin. Dosya, CachyOS kernel girdisinin kendi nixpkgs sürümü ile sistem nixpkgs revizyonunun ayrışması nedeniyle cache miss ve yerel kernel derleme ihtimalini dürüstçe belgeliyor. Bu, ilk kurulumun çok uzun sürmesine yol açabilir; kesin bir sonuç olarak değil olasılık olarak ele alınmalı.

#### `nixos/flake.lock`

Geçerli JSON ve kilitlenmiş input revizyonlarını içeriyor. Sistem nixpkgs revizyonu ile CachyOS kernel girdisinin iç nixpkgs revizyonu farklı. Bu farklılık dosyanın bozuk olduğu anlamına gelmiyor; fakat kernel türetmesinin cache isabetini etkileyebilir. Nix evaluator bulunmadığı için kilitlenmiş girdilerin şu anda başarıyla değerlendirildiği burada doğrulanmadı.

#### `nixos/configuration.nix`

Sistemin ana modülü. UEFI/systemd-boot, kernel parametreleri, AMD grafik, libvirt, VFIO hook wrapper'ı, Snapper, zram, SSH, fail2ban, oyun araçları, Ollama/ROCm, Vulkan implicit layer, Gamemode ve CPU zamanlayıcı ayarları burada. `vfioHook`, Bash ve gereken sistem araçlarının Nix store yollarını PATH'e ekliyor; hook'un libvirt'in gerçekten taradığı `/var/lib/libvirt/hooks/qemu.d/` yoluna kurulması amaçlanıyor.

Olumlu noktalar: IOMMU parametresi mevcut; hook başarısızlığı için doğrulama/rollback düşünülmüş; suspend/rescan varsayılan olarak kapalı; SSH parola girişleri ve root SSH kapalı; Ollama model hazırlığı el ile tetikleniyor ve indirme başarısızlığı için hata kontrolü var.

İnceleme notları:

- `system.stateVersion = "26.05"` makinenin gerçek ilk kurulum sürümüne göre teyit edilmeli.
- `boot.initrd.availableKernelModules` içine `amdgpu` eklenmesi hedef kurulumda gerçekten gerekli mi (`C17`) statik incelemeyle belirlenemez.
- Ownership oneshot dizinleri en fazla iki seviye tarıyor ve hataları `|| true` ile yok sayıyor. Hedef VM dosyalarının gerçek konum/izinleri açılıştan sonra doğrulanmalı.
- `warn-dirty = false` yerel flake çalışma ağacı kirli uyarılarını bastırıyor. Rebuild öncesi `git diff` inceleme ihtiyacı yorumlarda da belirtilmiş; bu güvence değil, kolaylık ayarı.
- `nowatchdog` ve `nmi_watchdog=0` düşük jitter için tanı kabiliyetini azaltıyor. `usbcore.autosuspend=-1` boşta güç tüketimini artırabilir. Bunlar kullanım amacına göre bilinçli tercih olmalı.
- `power-profiles-daemon`, `ananicy-cpp` ve Gamemode birbirinden farklı CPU/süreç önceliklerini etkileyebiliyor. Kod bunu bilinen bir uzlaşma olarak belgelemiş; ancak gerçek frametime/jitter ölçümleri olmadan en iyi kombinasyon olduğu söylenemez.
- `services.openssh.enable = true`, fakat parola doğrulaması kapalı ve `authorizedKeys.keys` varsayılan olarak boş. Bu durumda yeni sistemde SSH ile oturum açılamaz; uzaktan erişim istenmiyorsa servisi tamamen kapatmak daha sade.
- Oyun odaklı çok sayıda paket kuruyor. Bu kişisel workstation konfigürasyonu açısından anlaşılır; ancak daha küçük bir kurulum hedefleniyorsa paket listesi ve sistem kapanış süresi ayrıca değerlendirilmelidir.

#### `nixos/hardware-configuration.nix`

Btrfs root UUID'si, LUKS UUID'si, EFI UUID'si ve swap UUID'si içeren makineye özgü dosya. `/`, `/home`, `/nix`, `/var/log`, `/.snapshots`, `/home/.snapshots` montajlarını ve çeşitli alt hacimleri belirliyor. `/home/.snapshots` montajı `neededForBoot = true`; bu alt hacim önceden oluşturulmadıysa açılış acil kipte sonlanabilir. `install.sh` ve kurulum rehberi bu hazırlığı ele alıyor.

LUKS2 `allowDiscards = true` ayarı SSD discard bilgisini şifreleme katmanından geçirir; bunun gizlilik/perfomans dengesi olduğu bilinmeli. Swap bölümü şifresiz. Dosyadaki UUID'ler bir başka makine için tekrar kullanılmamalı.

#### `nixos/home.nix`

1.700 satır civarındaki Home Manager yapılandırması Hyprland, Hyprlock, Waybar, GTK, tuş kısayolları, mpvpaper, hypridle, MangoHud, `lsfg-vk`, Fish ve çeşitli oyun/çeviri yardımcılarını bir araya getiriyor. Birçok config inline tanımlanmış; dosyanın boyutu ve çoklu sorumlulukları bakım maliyetini artırıyor ama depodaki tek doğruluk kaynağı olarak dokümante edilmiş.

Kontrol edilmesi gerekenler:

- `home.stateVersion = "26.05"` gerçek ilk Home Manager kurulumuna göre teyit edilmeli.
- Varsayılan `gitName = "changeme"`, `gitEmail = "you@example.com"`, monitör çıkışı `DP-3` ve wallpaper yolu makinenize göre değiştirilmezse istenmeyen sonuç verir. README ve kurulum yönergesi bu varsayılanları açıklıyor.
- Hyprland monitör kuralı `monitor = ,preferred,auto,1` bir catch-all kuralı. Sözdizimi hatası olarak değerlendirilmemeli; çok monitörlü düzende her çıkışa uygulanmasının istenip istenmediğine karar verilmeli.
- WuWa OCR otomasyonu ekran görüntülerini sabit/varsayılan koordinatlarla kesiyor ve geometri için ortam değişkeni sağlıyor. Farklı çözünürlük veya çoklu monitörde ayrıca test gerektirir. OCR sonucu önbelleğe yazılabiliyor; bu yüzden oyun içi metin yerel diskte kalabilir.
- Yerel Ollama'ya gönderilen OCR metni, varsayılan yapılandırmada yerel model iş akışı. Buna karşılık `trans -b :tr` kullanan çeviri kısayolu harici çevrimiçi çeviri hizmetine veri gönderebilir; özel metinlerde bunun gizlilik etkisini dikkate alın.
- OCR normalizasyonu bazı ASCII dışı karakterleri/simgeleri temizlediği için OCR metni anlam kaybedebilir; bu bir güvenlik hatasından çok çeviri kalitesi kısıtıdır.
- `scripts/extract-embedded-scripts.py`, bu dosyanın inline Bash'ini CI için çıkarmaya çalışıyor. Script'lerin ayrı dosyalara bölünmesi bakım ve lint doğruluğunu artırabilir.
- `systemd.user.services` ile mpvpaper/watchdog/hypridle etkileşimleri pencere olayları ve GameMode durumuna bağlı. Gerçek bir oyun açılış/kapanış döngüsüyle test edilmelidir.

### VFIO/libvirt ve tanılama yardımcıları

#### `nixos/hooks/qemu`

Tek VM (`TARGET_VM="win10"`) için çalışan VFIO yaşam döngüsü hook'u. Başlangıçta süreç/GPU kullanımını kontrol etmeye çalışıyor, masaüstü ve servisleri kapatıyor, cihazları `vfio-pci`'ye bağlıyor ve bağlanmayı sysfs üzerinden doğruluyor. Hata durumunda geri alma ve sinyal yakalama mantığı var. VM kapanırken AMD sürücüsünü yeniden bağlayıp VT/EFI konsollarını ve greetd'i geri açmayı deniyor.

İyi tasarım kararları: `fuser` yokluğunu GPU'nun boş olduğuna dair kanıt saymama; cihaz aygıt düğümlerini kontrol etme; sadece hedef VM'yi filtreleme; `SIGKILL` ve kernel kilidiyle kurtarma garantisi olmadığını açıklama; riskli suspend/rescan yöntemini varsayılan olarak kapalı tutma.

Kalan riskler: tek GPU nedeniyle host görüntüsünün kaybı yapısal; reset hatası gerçek donanımda çözülemeyebilir; `release` sırasında sürücü geri bağlama başarısız olsa bile greetd başlatma deneniyor, bu durumda grafik oturumu açılamayabilir; log ve tty uyarıları kullanıcı için kritik. Bu yüzden hook'un sağlamlığını yalnızca sözdizimiyle kanıtlamak mümkün değil.

Libvirt hook çağrı sözleşmesi kaynak dokümanında `qemu <guest> prepare begin -` ve kapatırken `qemu <guest> release end <reason>` biçiminde açıklanıyor; koddaki ilk iki argümanı `GUEST` ve `ACTION` olarak yorumlamak bu sözleşmeyle uyumlu. Resmî doküman: https://libvirt.org/hooks.html.

#### `vm-xml/win10.xml`

`win10` adıyla 6 vCPU'lu Windows domain'i; Q35 makine türü, OVMF/TPM, 120G qcow2, Windows ve VirtIO ISO'ları, virtio ağ ve iki PCI hostdev içeriyor. Üretim XML'inde grafik konsol bilerek yok (`video model type="none"`); gerçek görüntü GPU passthrough üzerinden bekleniyor. Klavye/fare için aktif USB hostdev tanımı olmadığından guest'e fiziksel giriş cihazı aktarımı ayrıca yapılandırılmalı.

Kaynak PCI adresleri kurulum öncesi varsayımdır. `managed="no"` kullanımı cihaz sürücülerinin devrini dış hook'a bırakıyor. `qemu.runAsRoot=false` nedeniyle disk, NVRAM ve TPM state izinleri kritik. OVMF loader/template yolları pinned NixOS/libvirt runtime'ına bağlı; gerçek host'ta yolları doğrulayın.

#### `scripts/prepare-vm-diagnostic.py`

Üretim XML'ini ezmeden ayrı XML üretmeyi, loopback (`127.0.0.1`) VNC ve virtio video eklemeyi hedefliyor. Girdi/çıktı yolunun aynı olmasını ve mevcut çıktının üzerine yazmayı reddediyor; XML'i `ElementTree` ile doğruluyor; geçici dosya + atomik replace ve 0600 izin kullanıyor. Bunlar iyi korumalar.

Önemli ayrıntı: üretilen XML domain adını `win10` olarak koruyor. `virsh define` bunu ikinci bir VM olarak değil mevcut `win10` tanımı olarak kaydeder. README bunu doğru şekilde uyarıyor; tanılama bitince özgün üretim XML'ini tekrar `virsh define` etmek gerekiyor.

#### `scripts/extract-embedded-scripts.py`

CI'nin `home.nix` içine gömülü Bash betiklerini çıkarması için dar amaçlı bir yardımcı. Kaynakta belirli regex marker'larına ve satır yapısına bağlı. İsimli işaretleyici/format değişirse bazı script'leri bulamayabilir; CI'nin tam yedi çıktı beklemesi kaçırılan blokların bir kısmını tespit eder. Nix indented string'ini genel olarak parse etmediğinden, regex dönüşümleri değişen içerikte dikkatle doğrulanmalı.

### Depo/akış eşleştirmesi

#### `.git` metadata'sı

ZIP içinde Git nesneleri ve örnek hook dosyaları da bulunuyor. Güncel HEAD tek bir `Add files via upload` commit'i olarak görünüyor; tarihçe sınırlı olduğu için eski tasarım kararlarını Git blame/commit geçmişinden güvenilir biçimde izlemek mümkün değil. Bu, uygulama kusuru değil, denetlenebilirlik sınırlaması.

## 5. Dosyalar arası temel bağımlılık haritası

1. **Kurulum:** `KURULUM.md` / `install.sh` → `/etc/nixos/nixos/` içine flake ve Nix yapılandırmaları → kullanıcıya özel `hardware-configuration.nix` ve `hashedPassword` hazırlanır.
2. **Sistem derlemesi:** `nixos/flake.nix` + `flake.lock` → `configuration.nix` → `hardware-configuration.nix`, Home Manager `home.nix` ve `hooks/qemu` dosyasını okur.
3. **Host oturumu:** `configuration.nix` greetd/Hyprland, AMD grafik, kernel parametreleri, oyun/çeviri paketleri, libvirt ve sahiplik oneshot'ını açar.
4. **VM tanımı:** `install.sh` PCI adreslerini hook ve `/var/lib/libvirt/win10.xml` dosyasına eşitler; kullanıcı qcow2/ISO/NVRAM yollarını doğrular; `virsh define` domain'i kaydeder.
5. **VM başlatma:** `systemd-run` → `virsh start win10` → libvirt `prepare` hook → host masaüstünü kapatıp GPU/audio'yu VFIO'ya bağla → QEMU/Windows başlat.
6. **VM kapanışı:** libvirt `release` hook → AMD host sürücüsünü geri bağlamayı dene → konsol ve greetd'i geri getir → gerekiyorsa loglardan kurtarma.

Bu zincirdeki en yüksek etkili kopma noktaları: gerçek makine UUID/alt hacimlerinin yanlış olması, hook/XML PCI adreslerinin ayrışması, disk/OVMF/ISO yollarının eksikliği ve GPU reset/geri bağlama başarısızlığıdır.

## 6. Önerilen uygulama sırası

### Yeni makineye kurmadan önce

1. `nixos/hardware-configuration.nix` dosyasını kendi makinenizde `nixos-generate-config` ile üretin; root, EFI, LUKS, Btrfs ve swap UUID'lerini çapraz kontrol edin.
2. `system.stateVersion` ve `home.stateVersion` değerlerini ilk kurulum sürümünüzle doğrulayın.
3. GPU ve HDMI audio PCI adreslerini `lspci -nn` ile bulun, aynı IOMMU grubunda olup olmadıklarını inceleyin; XML ve hook adreslerinin aynı olduğundan emin olun.
4. Disk imajı, Windows ISO, VirtIO ISO ve OVMF NVRAM template yollarını kontrol edin.
5. SSH gerekmiyorsa SSH servisini kapatın; gerekiyorsa önce yetkili public key ekleyin.
6. Açık swap ve ek binary cache güven sınırını bilinçli değerlendirip kararınızı yazılı hale getirin.

### Yeniden başlatma ve VM testi öncesi

1. `nix flake check --no-build --show-trace --no-update-lock-file`.
2. `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath`.
3. `shellcheck -S warning install.sh nixos/hooks/qemu` ve `home.nix` içinden çıkarılan yedi betiği ShellCheck'ten geçirme.
4. `nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos`.
5. Yeniden başlatma sonrası `libvirtd-qemu-ownership` durumu, swtpm klasör izinleri ve OVMF dosyalarının varlığını doğrulama.
6. Normal VM kapanışı, ikinci başlatma ve zorla kapatma senaryolarıyla GPU'nun geri dönüşünü gerçek RX 6700 XT üzerinde test etme.

### Kalıcı bakım için

- `install.sh` içindeki hardware-configuration kopyalamasına diff/onay ekleyin.
- XML yazımını geçici dosya ve atomik rename ile yapın.
- README’deki `assets/` dokümantasyon farkı takip düzeltmesinde giderildi.
- Gömülü Bash betiklerini mümkünse ayrı kaynak dosyalara taşıyın.
- Arşivdeki tarihsel raporları değişiklik gerekçesi için saklayın ama yeni kodun doğrulanması yerine kullanmayın.

## 7. Son karar

Depo, amacı ve bilinen kısıtları hakkında oldukça açık; VFIO hook'unda gerçek hata durumları ele alınmış ve geçmiş denetim bulguları yönetilmeye çalışılmış. Statik incelemede dosya ayrıştırma düzeyinde bariz bir bozulma görülmedi. Bununla birlikte, **yüksek risk taşıyan ana doğruluk alanı kod sözdizimi değil, hedef makinenin depolama/OVMF düzeni ve tek GPU'nun fiziksel reset/geri bağlanma davranışıdır.** Bunlar yalnızca hedef donanım üzerinde, kurtarma yolu hazırken doğrulanabilir.

Bu rapor statik kaynak incelemesidir; “sorunsuz çalışır” sertifikası veya gerçek sistem üzerinde güvenlik garantisi değildir.

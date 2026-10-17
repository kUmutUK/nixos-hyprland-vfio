# `roscaa-stack/dotfiles` → NixOS/Hyprland/VFIO uyarlama raporu

**Tarih:** 18 Ekim 2026  
**Hedef:** yüklenen `nixos-hyprland-vfio` yapılandırması  
**Tema kaynağı:** <https://github.com/roscaa-stack/dotfiles>

## Yönetici özeti

`roscaa-stack/dotfiles`, Arch Linux üzerinde hazırlanmış, Hyprland merkezli bir masaüstü görünüm/uygulama deposudur. Yüklenen depo ise Nix Flake + Home Manager tabanlı, AMD GPU'yu Windows 10 sanal makinesine VFIO ile devreden, makineye özel bir NixOS sistemi. İki depoyu birleştirirken Arch'a özel komutları ya da tüm Hyprland yapılandırmasını kopyalamak doğru olmazdı.

Bu uyarlama, hedef deponun estetik karakterini (pembe/teal/sarı vurgular, koyu arka plan, Bibata imleci, Tela-circle simgeleri, Rofi/Kitty teması) mevcut NixOS yapılandırmasının içine taşır; disk, boot, kernel, PCI kimlikleri, VFIO hook'ları, Windows VM tanımı ve mevcut kullanıcı kısayollarını korur.

## İncelenen yerel depo

ZIP içindeki Git çalışma ağacı ve NixOS projesi incelendi. Ana dosya grupları:

- `nixos/flake.nix` ve flake kilidi: `nixos-unstable`, Home Manager ve CachyOS kernel girdileri ile `lsfg-vk` flake'i.
- `nixos/configuration.nix`: NixOS servisleri, AMD/RADV grafik yığını, greetd/tuigreet, sistem paketleri, oturum değişkenleri ve kullanıcı tanımı.
- `nixos/hardware-configuration.nix`: EFI, LUKS2, Btrfs alt birimleri ve swap için bu makineye özel UUID/aygıt tanımları.
- `nixos/home.nix`: Hyprland, Hyprlock, Waybar, GTK CSS, uygulama ayarları, kullanıcı servisleri ve gömülü yardımcı betikler.
- `nixos/hooks/qemu`, `nixos/vm-xml/win10.xml` ve `nixos/vm-xml/`: GPU'yu VM'ye bağlama/ana sisteme döndürme akışı ve Windows VM XML'i.
- `install.sh`, `scripts/` ve `.github/workflows/check.yml`: yükleyici, teşhis/regresyon kontrolleri ve CI kapıları.
- README, Türkçe kurulum belgesi, değişiklik geçmişi ve katkı yönergeleri.

### Yerel yapılandırmada kritik noktalar

- Home Manager kullanıcısı `localhost`; home dizini `/home/localhost`. Hedef dotfiles deposundaki `/home/kyokino` yolları bu sistemle uyuşmuyor.
- Oturum kabuğu Fish. Kaynaktaki `.zshrc`, Oh My Zsh/Powerlevel10k ve Arch odaklı eklenti/komutlar Fish'e doğrudan konulamaz.
- `nixos/home.nix`, `SUPER+A` kısayolunda `-theme arthur` seçeneğini kullanıyordu. `arthur` Rofi ile gelen stok temalardan biridir; fakat bu seçenek yeni özel temayı geçersiz kılacağından uyarlama standart `rofi -show drun` çağrısına dönüyor ve Nix-managed temayı kullanıyor.
- Mevcut Waybar modülleri GPU/CPU/sıcaklık/GameMode/MPRIS, ağ, ses ve tepsi entegrasyonlarını içeriyor. Kaynaktaki Waybar JSON'unu kopyalamak bu modülleri kaybettirir; dolayısıyla var olan modül tanımı korunup CSS ve boşluklar değiştirildi.
- Hyprland'deki monitör adı, Türkçe klavye, özel kısayollar, mevcut yardımcı komutlar, oyun kipleri ve mpvpaper watchdog korunuyor.
- `hardware-configuration.nix`, kernel seçimi, bootloader, kernel parametreleri, VFIO/QEMU hook'ları, VM XML'i ve flake girdileri bu görsel uyarlamada değiştirilmedi.

## Kaynak depoda saptanan ve taşınmayan parçalar

1. **Arch güncelleme komutu:** kaynak `systemupdate.sh` `/etc/arch-release` yoksa çıkıyor ve Arch/pacman/AUR araçlarına bağlı. NixOS'a kopyalanmadı.
2. **Sabit kullanıcı yolları:** `/home/kyokino/...` ve onun altında bulunduğu varsayılan `~/.config/hyprdots/scripts` yolları taşınmadı.
3. **Dizüstü donanımı:** kaynak Waybar ayarındaki `intel_backlight` ve batarya merkezli görünüm, AMD masaüstü hedefinde varsayılmadı.
4. **Kaynağa özel betikler:** `cpuinfo`, `gpuinfo`, `logoutlaunch`, `swwwallpaper` ve benzer Hyprdots betikleri, bağımlılıkları ve bekledikleri dosyalar bu sisteme ait değil; kopyalanmadılar.
5. **Kaynaktaki tam Hyprland dosyası:** `kb_layout = us`, `epic mouse V1`, başka `themes/` dosyaları ve ek betikler gibi makineye özel kabuller içeriyor. Bu dosyanın tamamı mevcut `hyprland.conf` üzerine yazılmadı.
6. **Zsh/Powerlevel10k kurulumu:** Fish giriş kabuğu korunuyor. Yalnızca eza tabanlı gezinme takma adları Fish'e uyarlandı; Arch'a özel `pacman` güncelleme alias'ları aktarılmadı.
7. **Sabit wallpaper:** kaynak Hyprlock dosyası `/home/kyokino/Pictures/...` gibi bir anime görselinin mevcut olduğunu varsayıyor. Bu sistem için dış görsel gerektirmeyen bir tema seçildi; kullanıcıya otomatik wallpaper atanmadı.

## Uyarlanan dosyalar ve değişiklikler

### `nixos/home.nix`

- GTK CSS vurgu ve yüzey renkleri pembe (`#EAB2C2`), teal (`#76C4D7`), sarı (`#D9C95E`), koyu lacivert (`#1B1E25`) ve açık metin (`#CCD9FF`) paletine uyarlandı.
- Hyprland aktif kenarlığı pembe-teal gradyana dönüştürüldü; `SUPER+A` Rofi çağrısı özel Nix-managed tema kullanılacak şekilde ayarlandı.
- Hyprlock renkleri paletle uyumlu hâle getirildi; desteklenen mevcut Hyprlock alanları ve ses/ağ/metin komutları muhafaza edildi.
- Waybar'ın mevcut JSON modül listesi ve veri kaynakları korunarak CSS yeniden yazıldı. Takvim renkleri ve üst boşlukları değiştirildi.
- GTK simge teması `Tela-circle-dracula`, imleç `Bibata-Modern-Ice` ve boyutu 20 olarak değiştirildi.
- Nix yönetimindeki Rofi teması, Kitty yapılandırması/renkleri, Ranger küçük ayar dosyası ve Fish alias dosyası eklendi.
- `eza`, `ranger` ve `pywal16` Home Manager paket listesine alındı. Pywal otomatik başlatılmıyor; kullanıcı gerektiğinde `wal -i /dosya/yolu/duvar-kâğıdı.png` komutunu çalıştırabilir. Sabit palet kullanan CSS/Hyprlock/Rofi/Kitty ayarları Pywal çıktısına bağımlı bırakılmadı.

### `nixos/configuration.nix`

- Sisteme yayılan `XCURSOR_THEME`/`XCURSOR_SIZE` değişkenleri ve cursor paketi Bibata'ya uyarlandı.
- Disk, boot, kernel, VFIO, QEMU, ağ ve oturum açılışının geri kalanına müdahale edilmedi.

## Neden SDDM/diğer hedef varsayımları taşınmadı?

Kaynaktaki SDDM teması ve ilgili varsayımlar, bu sistemde zaten kullanılan greetd/tuigreet oturum açıcı ile değiştirilemez biçimde entegre değil. Sırf görünüş eşleştirmek için giriş yöneticisini değiştirmek masaüstünün açılmaması riskini gereksiz yükseltirdi. Benzer şekilde masaüstü oturumunu yöneten özgün Hyprland komutlarının üstüne kaynaktaki başlangıç betiklerini koymak oyun/VM geri dönüş akışını bozabilirdi.

## Uygulanan renk paleti

| Kullanım | Renk |
|---|---|
| Ana arka plan | `#1B1E25` |
| İkincil yüzey | `#232936` |
| Kenarlık | `#2F364A` |
| Metin | `#CCD9FF` |
| Pembe vurgu | `#EAB2C2` |
| Teal vurgu | `#76C4D7` |
| Sarı vurgu | `#D9C95E` |
| Soluk metin | `#8290A8` |

## Dosya envanteri: yüklenen NixOS deposu

ZIP arşivinde Git metadata'sı da vardı. Yapılandırma paketine `.git/` taşınmayacak. İncelenen kaynak deposunun 35 izlenen dosyası aşağıda tek tek sınıflandırılmıştır; bu liste uyarlama sırasında hangi dosyaların etkin yapılandırmaya ait olduğunu ve hangi dosyaların sadece tarihçe/test amaçlı kaldığını ayırır.

| Dosya | İçerik / uyarlama kararı |
|---|---|
| `.github/workflows/check.yml` | CI iş akışı. Nix flake değerlendirmesi, XML, installer/VFIO testleri ve gömülü betik kontrolleri için kapılar; değiştirilmedi. |
| `.gitignore` | Derleme/yerel sır ve geçici dosya filtreleri; değiştirilmedi. |
| `README.md` | Üst seviye mimari, riskler, kurulum ve klavye kısayolu dokümantasyonu. Uyarlama bölümü eklendi. |
| `CHANGELOG.md` | Sürüm ve değişiklik özeti; geçmiş notları olarak korundu. |
| `CONTRIBUTING.md` | Katkı ve doğrulama rehberi; korundu. |
| `DEGISIKLIK_GECMISI.md` | Uzun Türkçe değişiklik geçmişi; geçmiş belgesi olduğu için yapılandırma kaynağı olarak kullanılmadı. |
| `KURULUM.md` | Türkçe kurulum, disk/şifreleme ve kurulum adımları; donanıma özel bölümler mevcut sistemle karşılaştırıldı, otomatik uygulanmadı. |
| `LICENSE` | MIT lisansı; korundu. |
| `docs/REPAIR-AND-VALIDATION-REPORT.md` | Aktif onarım/doğrulama raporu; kontrol beklentilerini anlamak için referans alındı. |
| `docs/archive/ANALYSIS-2026-10-05-ZIP3-SUPERSEDED.md` | Eski ve açıkça superseded olarak işaretli analiz; aktif ayarların yerine kullanılmadı. |
| `docs/archive/APPLIED-FIXES.md` | Önceki düzeltmelerin tarihçesi; mevcut kodla çelişen eski açıklamalar için kaynak kabul edilmedi. |
| `docs/archive/FIX-REPORT-2026-10-13.md` | Tarihli düzeltme raporu; geçmiş kayıt. |
| `docs/archive/HISTORICAL-AUDITS.md` | Tarihsel denetimlerin dizini/özeti; etkin yapılandırma değil. |
| `docs/archive/INSTALL-SAFETY-FIXES-2026-10-12.md` | Yükleyici güvenliğiyle ilgili geçmiş rapor; gerçek davranış güncel `install.sh` ve testlerle karşılaştırıldı. |
| `docs/archive/NIXOS-HYPRLAND-VFIO-ANALYSIS.md` | Arşivlenmiş sistem analizi; yalnızca bağlam için kullanıldı. |
| `docs/archive/POST-FIX-VALIDATION-2026-10-12.md` | Önceki doğrulama kaydı; bu çalışmadaki testlerin yerine geçmez. |
| `docs/archive/README.md` | Arşiv klasörünün açıklaması; geçmiş belgesi. |
| `docs/archive/REMAINING-ISSUES-AUDIT-2026-10-09.md` | Eski açık konu listesi; güncelliği aktif dosya ve testlerle değerlendirilmeli. |
| `docs/archive/nixos-hyprland-vfio-analysis-v2-SUPERSEDED.md` | Açıkça eski/superseded analiz; aktif kaynak olarak kullanılmadı. |
| `docs/archive/nixos-hyprland-vfio-review-report.md` | Geçmiş inceleme raporu; aktif konfigürasyona doğrudan uygulanmadı. |
| `install.sh` | Donanım/PCI tespiti, yedekleme ve `/etc/nixos` dosyalarını dağıtma adımlarını yönetir. Çalıştırılmadı; executable modu korundu. |
| `nixos/flake.nix` | NixOS output'u, Home Manager ve dış flake girdileri/kernel overlay tanımı; değiştirilmedi. |
| `nixos/flake.lock` | Girdi revizyonları; aynı kalması için değiştirilmedi. |
| `nixos/configuration.nix` | Sistem servisleri, kernel/boot, AMD/RADV, greetd, kullanıcı ve paketler. Sadece global cursor değişkeni ve cursor paketi tema uyarlamasıyla değişti. |
| `nixos/hardware-configuration.nix` | Makineye özel EFI/LUKS/Btrfs/swap tanımları. Dokunulmadı; UUID'ler raporda tekrar edilmedi. |
| `nixos/home.nix` | Hyprland/Waybar/Hyprlock/GTK/uygulama ayarları ve HM yönetimli betikler. Görsel katman ve seçilmiş istemci ayarları burada uyarlanmıştır. |
| `nixos/hooks/qemu` | VM başlangıç/durdurma sırasında GPU/VFIO sürücülerinin el değiştirme akışı; değiştirilmedi. |
| `vm-xml/win10.xml` | Windows 10/Q35/OVMF VM tanımı ve PCI/USB aygıt geçişi; değiştirilmedi, XML regresyon testi tekrarlandı. |
| `scripts/extract-embedded-scripts.py` | Home Manager Nix metinlerinden shell betiği çıkarıp ShellCheck'e besleyen araç. 7 betik çıkarma beklentisi tekrar denetlendi. |
| `scripts/prepare-vm-diagnostic.py` | VM XML teşhis/düzenleme aracı; üretim XML'ini bozmama testleriyle korunmuştur. |
| `scripts/test-installer-invariants.sh` | Yükleyici, VFIO, ağ/SSH ve seçili konfigürasyon değişmezlerini test eder; tekrar çalıştırıldı. |
| `scripts/test-installer-rollback.sh` | Yükleyicinin hata halinde yedekleri geri yüklemesini test eder; tekrar çalıştırıldı. |
| `scripts/test-vfio-hook-driver-state.sh` | GPU sürücü durumları ve VM öncesi servis durumunu regresyonla test eder; tekrar çalıştırıldı. |
| `scripts/test-vm-diagnostic.py` | VM video aygıtı teşhis aracı için pozitif/negatif girdileri test eder; tekrar çalıştırıldı. |
| `scripts/test-vm-xml.py` | VM XML invariantları ve QEMU hook PCI adresi eşleşmesini doğrular; tekrar çalıştırıldı. |

## İncelenen upstream `roscaa-stack/dotfiles` dosyaları

Aşağıdaki dosyalar kaynak depoda doğrudan incelendi; uyarlama kararı dosya bazında belirtildi. Kaynak deposunun tamamını Linux/NixOS'a aynen taşımak yerine, etkin makine ayarlarıyla kesişen dosyalar ve bağımlılıkları önceliklendirildi.

| Upstream dosya | Bulgular / karar |
|---|---|
| `README.md` | Arch, Hyprland ve Bocchi teması odaklı uygulama listesini/bağımlılıkları açıklar; NixOS portunun kaynak envanteri olarak kullanıldı. |
| `.zshrc` | Oh My Zsh, Powerlevel10k, Arch eklentisi, `exa`, `catnip` ve Pywal ön kabulleri var. Fish giriş kabuğu nedeniyle aynen alınmadı. |
| `.p10k.zsh` | Powerlevel10k prompt ayrıntıları; Zsh kurulumu taşınmadığı için devre dışı bırakıldı. |
| `.config/hypr/hyprland.conf` | `us` klavye, belirli fare ve mutlak script/wallpaper yolları, ek source dosyaları ve açılış betikleri var. Ana Hyprland dosyası üstüne yazılmadı. |
| `.config/hypr/animations.conf` | Animasyon değerleri; mevcut Hyprland animasyonlarıyla çakışmaması için doğrudan kopyalanmadı. |
| `.config/hypr/keybindings.conf` | Kitty/Dolphin/Firefox gibi komutlar ve upstream'e özel kısayollar; mevcut kısayollar korunup yalnızca Rofi çağrısı düzeltildi. |
| `.config/hypr/windowrules.conf` | Kaynağa özel pencere eşleştirmeleri; taşınmadı. |
| `.config/hypr/monitors.conf` | Çıktı/monitör adı gibi makineye özgü değerler; hedef ekran adı bilinmediği için taşınmadı. |
| `.config/hypr/userprefs.conf` | Kaynağa özgü kullanıcı tercihleri; taşınmadı. |
| `.config/hypr/themes/common.conf` | Bibata imleci, GTK/Cantarell/CaskaydiaCove ve dekorasyon/blur tercihleri; imleç/tema fikri uyarlanırken mevcut font/blur davranışı korundu. |
| `.config/hypr/themes/theme.conf` | `/home/kyokino/...` mutlak yolundan Catppuccin dosyasını seçiyor; doğrudan kullanılmadı. |
| `.config/hypr/themes/Catppuccin-Mocha.conf` | Upstream tema dosyasının GTK/simge teması ve kenarlık paleti; bazı bileşenlerin Catppuccin Mocha tabanı korunurken Rofi/Waybar/Hyprland vurgu renkleri ayrıca uyarlanmıştır. |
| `.config/hypr/themes/colors.conf` | Pembe/teal border paleti; mevcut Hyprland vurgularına dönüştürüldü. |
| `.config/hypr/hyprlock.conf` | `/home/kyokino/Pictures/...` wallpaper ve Pywal cache gerektiriyor; yerine sabit, görselsiz ve mevcut hyprlock sürümüne uygun renk uyarlaması yapıldı. |
| `.config/waybar/config.jsonc` | 1900 genişlik, `intel_backlight`, `/home/kyokino/.config/hyprdots/scripts` ve Arch güncelleme betiği varsayımları var. JSON modül yapısı taşınmadı; yerel mevcut modüller korundu. |
| `.config/waybar/style.css` | Harici bir Waybar theme dosyası import ediyor ve pembe/teal stil içeriyor; renk anlayışı Home Manager CSS'ine uyarlandı. |
| `.config/waybar/themes/Wall-Dcol.css` ve theme yönlendirmesi | Mutlak Waybar tema yolu; HM tarafından yönetilen tek bir CSS oluşturmak için taşınmadı. |
| `.config/rofi/config.rasi` | Rofi yapılandırması ve temaya ilişkin upstream varsayımları; standart Rofi modları ve yerel tema ile yeniden yazıldı. Rofi belgeleri `arthur` temasını stok temalardan biri olarak listeler; bu port özel paleti kullanır. |
| `.config/rofi/themes/theme.rasi` | Pembe, teal, sarı ve koyu yüzey paleti; `nixos/home.nix` içine Nix-managed Rasi tema olarak taşındı. |
| `.config/kitty/kitty.conf` | JetBrainsMono Nerd Font, 11pt ve 20px padding; Nix-managed Kitty config olarak uyarlandı. |
| `.config/kitty/themes/theme.conf` | Terminal renk paleti; seçilmiş palete uyarlanıp Kitty config'ine eklendi. |
| `.config/ranger/rc.conf` | Büyük ölçüde ranger varsayılanlarından oluşuyor; yalnızca küçük ve makineye güvenli preview/hidden-file tercihleri alındı. |
| `systemupdate.sh` | `/etc/arch-release`, `checkupdates` ve Arch/AUR/pacman araçlarına bağlı; kesinlikle taşınmadı. |
| `cpuinfo.sh`, `gpuinfo.sh` | Kaynağa özgü donanım gösterimi ve ek betik bağımlılıkları; Waybar veri kaynaklarıyla uyumlu olmadığı için taşınmadı. |
| `volumecontrol.sh`, `logoutlaunch.sh`, `swwwallpaper.sh`, pil ve portal yardımcı betikleri | Upstream dizin/uygulama adlarını ve açılış düzenini varsayıyor; mevcut NixOS servislerini/Waybar modüllerini bozmamak için taşınmadı. |

## Kontroller ve bilinen sınırlar

Uyarlamadan önce kaynak depoda çalışan mevcut otomatik kontroller şunlardı: VM XML invariant testi, VM teşhis testi, VFIO hook sürücü durumu regresyonu, yükleyici invariantları, yükleyici geri alma testi, gömülü betik çıkarımı ve XML'in iyi biçimlilik testi. Uyarlamadan sonra bu kontroller yeniden çalıştırılmalı; gömülü betik sayısı CI'ın beklediği 7'de kalmalı.

Bu çalışma ortamında `nix`/`nix-instantiate` ve `shellcheck` bulunmadığından `nix flake check`, Home Manager değerlendirmesi ve ShellCheck burada çalıştırılamıyor. Bu, değerlendirme/derleme hatası bulunduğu anlamına gelmez; ama derlemenin doğrulandığı anlamına da gelmez. Gerçek sistemde `nixos-rebuild dry-build` ve sonra dikkatli test gerekli.

### Güvenli deneme sırası

1. `/etc/nixos` içindeki çalışan yapılandırma ve flake kilidini ayrıca yedekleyin.
2. Uyarlama deposunu mevcut `/etc/nixos` üzerine körlemesine kopyalamayın; kendi kullanıcı/hardware dosyanızla farkını gözden geçirin.
3. Önce hedef sistemde `nix flake check --no-build --show-trace --no-update-lock-file` ve uygun flake dizini/çıktı adıyla `nixos-rebuild dry-build` çalıştırın.
4. Ekran kilidi, klavye, Rofi, Waybar ve GTK uygulamalarını GPU passthrough testinden bağımsız doğrulayın.
5. VFIO/VM testi yapılacaksa yerel TTY ve çalışan SSH erişimi gibi kurtarma yolunu hazır tutun. Tek GPU passthrough, VM çalışırken ana masaüstünün grafik oturumunu durdurabilir.

Bu rapor ve uyarlanmış depo bir dosya incelemesi/konfigürasyon uyarlamasıdır; canlı fiziksel donanım üzerinde çalıştırılmış ya da GPU reset/VM açılışıyla doğrulanmış değildir.

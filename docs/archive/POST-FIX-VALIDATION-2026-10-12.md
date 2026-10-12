# 2026-10-12 — VFIO düzeltmeleri sonrası doğrulama

Bu kontrol listesi kaynak koddan otomatik doğrulanamayan, hedef NixOS makinesinde yapılması gereken kontrolleri ayırır. Canlı sistem kontrolleri bu arşiv hazırlanırken çalıştırılmadı.

## Uygulanan kaynak düzeltmeleri

- **N9:** `install.sh` yürütülebilir moda (`100755`) alındı; Git indeksi de aynı modu kaydediyor. README'de `chmod +x install.sh` ve `bash ./install.sh` alternatifi açıkça yer alıyor.
- **N5:** Installer, dosyaları kopyalamadan önce var olan `system.stateVersion` ve `home.stateVersion` sabit değerlerini okur ve yeni şablona taşır. Kaynak mevcut ama değer otomatik bulunamazsa kullanıcıdan açıkça ister; geçerli bir `YY.MM` değeri girilmezse dosya kopyalamaya başlamadan durur. İlk kurulumda mevcut dosya olmadığından depo varsayılanı korunur.
- **N7:** Installer, GPU için PCI sınıfı `0300` (VGA), `0302` (3D) veya `0380` (display controller); GPU ses fonksiyonu için `0401`/`0403` sınıf kodlarını doğrular. Sınıf uyuşmazlığı kurulumun durmasına yol açar.
- **N8:** `gpu_drm_card()` yalnız gerçek `cardN` sysfs eşleşmesini kabul eder. Eşleşme yoksa `card0` varsaymaz; hata döndürür ve `prepare` akışı geri alma yoluna girer.
- **C17:** `amdgpu`'nun initrd içinde erişilebilir yapılmasının host Radeon ekranının erken açılış gerekçesi ve isteğe bağlı olduğu, VFIO'nun kendisi için gerekli olmadığı yapılandırma yorumunda belirtilmiştir.
- **N6:** Windows 10 EOL riski bilinçli olarak kabul edildi; bu arşivde Windows VM nesli değiştirilmedi.

## Hedef makinede yapılacak kontroller

### 1. N9 — Git modu

Repo kökünde:

```bash
git ls-files -s install.sh
stat -c '%a %A %n' install.sh
```

Beklenen: Git indeksi `100755`, dosya modu `755`.

### 2. A3 — swtpm dizininin sahipliği/izinleri

```bash
stat -c '%A %U:%G %a %n' /var/lib/libvirt/swtpm
sudo find /var/lib/libvirt/swtpm -maxdepth 2 -printf '%M %u:%g %p\n' 2>/dev/null | head -80
sudo journalctl -u libvirtd -u virtqemud --since today --no-pager | grep -iE 'swtpm|permission|denied' | tail -80
```

Çıktıyı çalışan libvirt/swtpm servis kullanıcısı ve distro'nun varsayılan izinleriyle karşılaştırın. Yalnızca bu `stat` çıktısına bakarak toplu `chown -R` yapmayın.

### 3. C14 — `stateVersion` doğrulaması

```bash
grep -nE 'system\.stateVersion|home\.stateVersion' /etc/nixos/nixos/configuration.nix /etc/nixos/nixos/home.nix
git -C /path/to/nixos-hyprland-vfio log --oneline --all -- nixos/configuration.nix nixos/home.nix
```

Yüklenecek yapılandırmadaki `system.stateVersion`'ı mevcut makinenin gerçek kurulum uyumluluk tabanıyla karşılaştırın; sırf NixOS/flake kanalı yükseltildi diye değiştirmeyin. Home Manager `home.stateVersion` değerini de mevcut kullanıcı yapılandırmasıyla karşılaştırın. `/path/to/nixos-hyprland-vfio` yerine repo kökünü yazın.

### 4. C19 — OVMF dosyaları ve VM XML eşleşmesi

```bash
ls -l /run/libvirt/nix-ovmf/edk2-*
sudo virsh dumpxml win10 | grep -nE '<loader|<nvram|<hostdev|<source address|<type arch='
sudo virsh dominfo win10
```

XML'deki `<loader>` ve `<nvram>` yollarının mevcut OVMF dosyalarıyla eşleştiğini; iki PCI `<hostdev>` adresinin `nixos/hooks/qemu` içindeki `GPU_PCI`/`GPU_AUDIO` ile aynı olduğunu doğrulayın. `virsh dumpxml` yalnızca tanımlı domain'in XML'ini gösterir; dosyaların firmware için kullanılabilir olduğunu tek başına kanıtlamaz.

### 5. H10 — VM öncesi tanılama XML'i

İlk canlı VM denemesinden önce mümkünse production XML'in ayrı tanılama kopyasını üretin. Bu betik production XML'i yerinde değiştirmez ve çıktı yolu önceden mevcutsa çalışmayı reddeder:

```bash
sudo python3 /path/to/nixos-hyprland-vfio/scripts/prepare-vm-diagnostic.py \
  --input /var/lib/libvirt/win10.xml \
  --output /var/lib/libvirt/win10-diagnostic.xml
sudo virsh define /var/lib/libvirt/win10-diagnostic.xml
sudo systemd-run --unit=vmstart --collect /run/current-system/sw/bin/virsh start win10
sudo journalctl -u vmstart.service -b --no-pager
sudo virsh vncdisplay win10
```

Tanılama XML'i de `win10` domain adını kullandığından mevcut domain tanımını geçici olarak değiştirir; ikinci VM oluşturmaz. VNC yalnızca `127.0.0.1` adresine bağlıdır. Testten sonra `sudo virsh shutdown win10` ile VM'i kapatın, `sudo virsh domstate win10` ile kapalı olduğunu doğrulayın ve üretim tanımını geri yükleyin: `sudo virsh define /var/lib/libvirt/win10.xml`. VM'in GPU atama testine geçmeden önce yedek/erişim yolu ve host kurtarma yöntemi hazır olmalı.

### 6. Gerçek GPU passthrough testi

Statik kontroller gerçek GPU reset'ini doğrulayamaz. İlk denemede mümkünse SSH/TTY kurtarma yolu açık tutulsun; VM'i host masaüstünü kapatan hook'u atlatmadan, proje belgelerindeki kontrollü systemd-run yöntemiyle başlatın. Başlatma, guest içinde GPU görünmesi, normal kapatma ve ikinci başlatma döngülerinin her birini ayrı kaydedin. Ekranın geri gelmemesi durumunda Navi 2x reset sınırlaması nedeniyle host yeniden başlatması gerekebilir.

## Statik kontrollerin kapsamı

Bu liste `bash -n`, Python derleme, `win10.xml` XML ayrıştırma, `flake.lock` JSON ayrıştırma ve kaynak modu kontrolleriyle birlikte kullanılmalıdır. Nix Flake evaluation/build, ShellCheck ve gerçek host/VM testi ancak hedef ortamda çalıştırılabilir; arşiv dosyaları tek başına bunların yerine geçmez.

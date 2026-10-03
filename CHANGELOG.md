# 📜 Changelog

All notable changes to this project will be documented here.

This project follows:
- Keep a Changelog
- Semantic Versioning

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





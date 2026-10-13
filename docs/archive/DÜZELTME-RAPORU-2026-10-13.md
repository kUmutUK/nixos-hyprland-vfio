# Düzeltme Raporu — 2026-10-13

Bu paket, depoda aşağıdaki statik düzeltmeleri içerir.

1. **F3 — PCI domain:bus:slot eşleşmesi (`install.sh`)**: GPU ile HDMI/DP ses fonksiyonunun aynı fiziksel PCI aygıtına ait olması zorunlu.
2. **F4 — README bağlantısı (`README.md`)**: doğrulama belgesi `docs/archive/` altındaki gerçek konumuna bağlandı.
3. **F5 — monitör varsayılanı (`KURULUM.md`)**: `monitorOutput` varsayılanı `""` olarak belgelendi; kullanıcı tarafından örnek olarak girilecek DP çıkış adı ayrı tutuldu.
4. **F7 — IOMMU açıklaması (`nixos/configuration.nix`, README, KURULUM, hook)**: firmware/BIOS koşulları netleştirildi. Belgelenmiş bir AMD kernel parametresi olarak doğrulanmayan `amd_iommu=on` kernel parametre listesinden çıkarıldı; `iommu=pt` tek başına IOMMU etkinliğinin kanıtı olarak sunulmuyor.
5. **F10 — extractor marker filtresi (`scripts/extract-embedded-scripts.py`)**: extractor artık shebang'i kendisi ekleyerek yapılandırma metnini yanlışlıkla betik gibi kabul etmiyor; gerçek shebang ile başlayan gömülü blokları filtreliyor. CI'daki 7 betik beklenen sayısı korunuyor.
6. **F11 — GitHub Actions SHA pin (`.github/workflows/check.yml`)**: `actions/checkout` v4.4.0 commit SHA'sına sabitlendi.
7. **IOMMU grup raporu (`install.sh`)**: GPU ve ses farklı gruplardaysa iki grubun üyeleri de gösteriliyor.
8. **PCI domain yolu (`install.sh`)**: IOMMU grup dizinleri `0000:` domain'i sabit varsayılmadan tam PCI adresiyle oluşturuluyor.

## Yapılan kontroller

- `bash -n install.sh`: geçti
- `bash -n nixos/hooks/qemu`: geçti
- `scripts/test-vfio-hook-driver-state.sh`: geçti
- Extractor: 7 betik çıkardı; yedisinin `bash -n` kontrolü geçti
- `vm-xml/win10.xml` XML ayrıştırması: geçti
- `git diff --check`: geçti
- Yerel Markdown bağlantı kontrolü: kırık bağlantı bulunmadı

## Sınırlar

Bu ortamda Nix ve ShellCheck kurulu olmadığı için `nix flake check`, NixOS değerlendirmesi/build'i ve ShellCheck CI adımı çalıştırılamadı. Canlı sistemin BIOS/IOMMU durumu, swtpm sahipliği ve VM passthrough davranışı statik arşivden doğrulanamaz; bunlar ayrıca gerçek makinede test edilmelidir.

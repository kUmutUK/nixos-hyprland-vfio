# Arşiv — SÜPERSEDED analizler

Bu klasördeki belgeler **eski sürümlere karşı** yazılmıştır ve artık
koda bakarak doğrulanmamalıdır.

## `ANALIZ-2026-10-05-ZIP3-SUPERSEDED.md`

`nixos-hyprland-vfio(3).zip` @ commit `97a1665` için yazıldı.
Bu depodaki kod commit `0d35833` ("Add files into upload", zip (4)).

Yani belgedeki satır numaraları ve iki P1 bulgusu **bugün geçerli değil**:

| Bulgu | Bugünkü durum |
|---|---|
| #1 `{H:M}` / `{user}` literal metin | **Düzeltildi.** Artık `$TIME` / `$USER`; hyprlock 0.9.6 `IWidget::formatString` bunları substitute eder (`IWidget.cpp:200,208`) ve `updateEveryMs` ile otomatik tazeler. `assets/example.conf:79` da `text = $TIME` kullanıyor. |
| #2 Hyprland 0.56.2 `hyprland.lua`'ya öncelik veriyor, `.conf` yok sayılıyor | **Fiilen gerçekleşmiyor.** `Jeremy::getMainConfigPath()` önce `findConfig("hyprland","lua")` arar; ama `Hyprutils::Path::findConfig` yalnızca `XDG_CONFIG_HOME`, `XDG_CONFIG_DIRS` ve `/etc/xdg` altına bakar. NixOS'un `environment.pathsToLink = [ "/share/hypr" ]` ile koyduğu stub `/run/current-system/sw/share/hypr/hyprland.lua` bu dizinlerde **değil** → `~/.config/hypr/hyprland.conf` kazanır. |

Kalan maddelerin güncel hâli için `FIXES-2026-10-05.md` ve `FIX-MANIFEST.md`
dosyalarına bakın.

> Not: Bu belge ZIP adındaki (3)/(4) farkından dolayı yanıltıcı bir isimle
> duruyordu (`ANALIZ-2026-10-05.md`, yani en güncel görünen dosya). Arşivdeki
> ad artık hangi sürüme karşı yazıldığını açıkça söylüyor.

## `nixos-hyprland-vfio-analiz-v2-SUPERSEDED.md`

Bu repo'nun **ilk** bağımsız analiz raporu ("SÜRÜM 2"). `FIXES-2026-10-05.md`
ve `FIX-MANIFEST.md` onun devamı; ikisi de uygulanan düzeltmeleri kaydeder.
Bu üçü birbirinin farklı sürümlerini anlatıyor — güncel olan `FIXES-2026-10-05.md`
ve `FIX-MANIFEST.md`.

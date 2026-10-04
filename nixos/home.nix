{ config, pkgs, lib, ... }:

let
  gitName            = "Umpug";
  gitEmail           = "141457520+kUmutUK@users.noreply.github.com";
  monitorOutput      = "DP-3";
  hyprlandMonitorLine = "monitor = ,preferred,auto,1";
  wallpaperVideo     = "${config.home.homeDirectory}/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4";

  gamemodeNotifyScript = pkgs.writeShellScriptBin "gamemode-notify" ''
    NOTIFY_SEND="${pkgs.libnotify}/bin/notify-send"
    ${pkgs.dbus}/bin/dbus-monitor --session \
      "type='signal',interface='com.feralinteractive.GameMode'" |
    while read -r line; do
      if echo "$line" | grep -q 'GameRegistered'; then
        $NOTIFY_SEND -i games "🎮 GameMode" "Aktif – yüksek performans" -t 3000
      elif echo "$line" | grep -q 'GameUnregistered'; then
        count=$(${pkgs.systemd}/bin/busctl --user get-property com.feralinteractive.GameMode \
                  /com/feralinteractive/GameMode com.feralinteractive.GameMode ClientCount \
                  2>/dev/null | cut -d' ' -f2)
        if [ "$count" = "0" ]; then
          $NOTIFY_SEND -i games "🎮 GameMode" "Devre dışı – normal mod" -t 3000
        fi
      fi
    done
  '';

  gtkCss = ''
    @define-color accent_color              #cba6f7;
    @define-color accent_fg_color           #000000;
    @define-color accent_bg_color           #cba6f7;
    @define-color window_bg_color           #000000;
    @define-color window_fg_color           #ffffff;
    @define-color view_bg_color             #0a0a0a;
    @define-color view_fg_color             #ffffff;
    @define-color headerbar_bg_color        #000000;
    @define-color headerbar_fg_color        #ffffff;
    @define-color headerbar_border_color    #222222;
    @define-color headerbar_backdrop_color  #000000;
    @define-color headerbar_shade_color     #000000;
    @define-color card_bg_color             #111111;
    @define-color card_fg_color             #ffffff;
    @define-color card_shade_color          #000000;
    @define-color popover_bg_color          #111111;
    @define-color popover_fg_color          #ffffff;
    @define-color dialog_bg_color           #000000;
    @define-color dialog_fg_color           #ffffff;
    @define-color sidebar_bg_color          #000000;
    @define-color sidebar_fg_color          #ffffff;
    @define-color sidebar_border_color      #222222;
    @define-color warning_color             #f9e2af;
    @define-color error_color               #f38ba8;
    @define-color success_color             #a6e3a1;
    @define-color destructive_color         #f38ba8;
    @define-color destructive_bg_color      #f38ba8;
    @define-color destructive_fg_color      #000000;

    window, .background {
      background-color: @window_bg_color;
      color: @window_fg_color;
    }
    titlebar, headerbar {
      background-color: @headerbar_bg_color;
      color: @headerbar_fg_color;
      border-bottom: 1px solid @headerbar_border_color;
      min-height: 38px; padding: 0 8px;
    }
    titlebar button, headerbar button {
      min-height: 24px; min-width: 24px; padding: 2px; border-radius: 6px;
      background: transparent; color: @headerbar_fg_color;
    }
    titlebar button:hover, headerbar button:hover {
      background: alpha(@accent_color, 0.2);
    }
    button {
      background: @card_bg_color; color: @card_fg_color;
      border: 1px solid @headerbar_border_color; border-radius: 8px;
      padding: 6px 12px; min-height: 28px; transition: 0.15s;
    }
    button:hover { background: shade(@card_bg_color, 1.15); }
    button:active { background: shade(@card_bg_color, 0.9); }
    button.suggested-action {
      background: @accent_bg_color; color: @accent_fg_color; border-color: @accent_color;
    }
    button.destructive-action {
      background: @destructive_bg_color; color: @destructive_fg_color; border-color: @destructive_color;
    }
    button:disabled { opacity: 0.5; }
    entry {
      background: @view_bg_color; color: @view_fg_color;
      border: 1px solid @headerbar_border_color; border-radius: 8px;
      padding: 6px 10px; min-height: 28px;
    }
    entry:focus { border-color: @accent_color; box-shadow: 0 0 0 2px alpha(@accent_color, 0.3); }
    textview text, list, treeview, .view { background: @view_bg_color; color: @view_fg_color; }
    list row, treeview row {
      padding: 4px 8px; border-bottom: 1px solid alpha(@headerbar_border_color, 0.3);
    }
    list row:selected, treeview row:selected { background: @accent_bg_color; color: @accent_fg_color; }
    scrollbar { background: transparent; border: none; }
    scrollbar slider { background: @popover_bg_color; border-radius: 10px; min-width: 6px; min-height: 6px; }
    scrollbar slider:hover { background: @card_bg_color; }
    menu, popover {
      background: @popover_bg_color; color: @popover_fg_color;
      border: 1px solid @headerbar_border_color; border-radius: 10px; padding: 4px;
    }
    menuitem, modelbutton { padding: 6px 12px; border-radius: 6px; }
    menuitem:hover, modelbutton:hover { background: alpha(@accent_color, 0.2); }
    tooltip {
      background: @card_bg_color; color: @card_fg_color;
      border: 1px solid @headerbar_border_color; border-radius: 8px; padding: 4px 8px;
    }
    tooltip label { color: @card_fg_color; }
    paned separator { background: @headerbar_border_color; min-width: 1px; min-height: 1px; }
    infobar {
      background: @window_bg_color; border: 1px solid @headerbar_border_color;
      border-radius: 8px; margin: 4px; padding: 8px;
    }
    infobar.info { background: alpha(@accent_color, 0.1); border-color: @accent_color; }
    infobar.warning { background: alpha(@warning_color, 0.1); border-color: @warning_color; }
    infobar.error { background: alpha(@error_color, 0.1); border-color: @error_color; }
    notebook tab {
      background: @sidebar_bg_color; color: @sidebar_fg_color;
      padding: 6px 12px; border: 1px solid @sidebar_border_color; border-bottom: none;
      border-radius: 8px 8px 0 0;
    }
    notebook tab:checked { background: @window_bg_color; border-color: @headerbar_border_color; }
    progressbar trough { background: @view_bg_color; border-radius: 6px; min-height: 6px; }
    progressbar progress { background: @accent_bg_color; border-radius: 6px; }
    frame { border: 1px solid @headerbar_border_color; border-radius: 8px; padding: 4px; }
    switch { background: @popover_bg_color; border-radius: 12px; min-width: 44px; min-height: 24px; padding: 2px; }
    switch slider { background: @window_fg_color; border-radius: 10px; min-width: 20px; min-height: 20px; }
    switch:checked { background: @accent_bg_color; }
    switch:checked slider { background: @accent_fg_color; }
    checkbutton check, radiobutton radio {
      background: @view_bg_color; border: 1px solid @headerbar_border_color;
      color: @window_fg_color; min-width: 18px; min-height: 18px; border-radius: 4px; padding: 2px;
    }
    checkbutton check:checked, radiobutton radio:checked {
      background: @accent_bg_color; border-color: @accent_color; color: @accent_fg_color;
    }
    scale trough { background: @view_bg_color; border-radius: 6px; min-height: 6px; }
    scale highlight { background: @accent_bg_color; border-radius: 6px; }
    scale slider { background: @window_fg_color; border-radius: 10px; min-width: 16px; min-height: 16px; }
    separator { background: @headerbar_border_color; min-height: 1px; min-width: 1px; }
    entry placeholder { color: alpha(@window_fg_color, 0.5); }
    levelbar trough { background: @view_bg_color; border-radius: 4px; min-height: 6px; }
    levelbar block { background: @accent_bg_color; border-radius: 4px; }
    treeview expander { color: @window_fg_color; }
    calendar { background: @window_bg_color; color: @window_fg_color; }
    calendar:selected { background: @accent_bg_color; color: @accent_fg_color; }
  '';

  hyprlandConf = ''
    ${hyprlandMonitorLine}

    $accent = 0xcba6f7ff
    $bg     = 0x000000ff

    env = XCURSOR_SIZE,16
    env = XCURSOR_THEME,capitaine-cursors
    env = DISPLAY, :0

    input {
        kb_layout = tr
        follow_mouse = 1
        sensitivity = 0
        accel_profile = flat
    }

    general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        col.active_border = $accent
        col.inactive_border = $bg
        layout = dwindle
        allow_tearing = true
        resize_on_border = true
        no_focus_fallback = false
    }

    dwindle {
        smart_resizing = true
    }

    decoration {
        rounding = 10
        dim_inactive = false
        shadow {
            enabled = true
            range = 50
            render_power = 10
            offset = 0 5
            color = $bg
        }
    }

    animations {
        enabled = true
        bezier = smoothOut, 0.25, 0.05, 0.1, 1.0
        bezier = overshot, 0.05, 0.9, 0.1, 1.1
        bezier = bounce, 0.3, 1.6, 0.6, 1.0
        animation = windowsIn,  1, 7, smoothOut, slide
        animation = windowsOut, 1, 7, smoothOut, slide
        animation = fade,       1, 4, smoothOut
        animation = workspaces, 1, 5, overshot, slide
        animation = layers, 1, 6, overshot, fade
        animation = border, 1, 10, smoothOut
        animation = specialWorkspace, 1, 6, overshot, slidevert
    }

    misc {
        vrr = 2
        mouse_move_enables_dpms = true
        key_press_enables_dpms = true
        disable_hyprland_logo = true
        disable_splash_rendering = true
        force_default_wallpaper = 0
        animate_manual_resizes = false
        animate_mouse_windowdragging = false
        allow_session_lock_restore = true
        session_lock_xray = true
        enable_swallow = true
        swallow_regex = (kitty.*)
    }

    cursor {
        no_hardware_cursors = false
        inactive_timeout = 3
    }

    $mainMod = SUPER

    # Rofi teması (arthur) repoda hiçbir yerde bulunmuyordu; bu satır
    # rofi'yi temalı başlatmaya çalışıp düşüyordu. Varsayılan temaya dönüldü.
    bind = $mainMod, A, exec, ${pkgs.rofi}/bin/rofi -show drun
    bind = $mainMod, C, exec, kitty
    bind = $mainMod, Q, killactive
    bind = $mainMod, Return, exec, kitty
    bind = $mainMod, F, fullscreen
    bind = $mainMod, V, togglefloating
    bind = $mainMod, P, exec, grim -g "$(slurp)" - | wl-copy
    bind = $mainMod SHIFT, P, exec, grim -g "$(slurp)" - | satty -f - | wl-copy
    bind = $mainMod, Escape, exec, ${pkgs.hyprlock}/bin/hyprlock          # ← hyprlock yeni tuş
    bind = $mainMod, W, exec, ${pkgs.waypaper}/bin/waypaper

    bind = $mainMod, S, exec, pypr toggle term
    bind = $mainMod SHIFT, S, exec, pypr toggle music
    bind = $mainMod CTRL, S, exec, pypr toggle filemanager

    # ── Tekerlekle oda değiştirme ───────────────────────────────────
    # Hyprland v0.55.0'te tekerlek artık tuş değil EKSEN (axis) olayı
    # üretiyor. KeybindManager::onAxisEvent (KeybindManager.cpp:407-434)
    # dikey eksende e.delta<0 için "mouse_down", e.delta>0 için "mouse_up"
    # ismiyle handleKeybinds() çağırıyor. "scroll:down" / "scroll:up" isimleri
    # HİÇ üretilmiyor → eski satırlar config yüklenirken hatasız geçiyor,
    # basılınca da hiçbir şey olmuyordu.
    #
    # İkinci hata aynı satırlardaydı: "layoutmsg, cyclenext scroll".
    #   * "scroll" argümanı geçersiz;
    #   * dwindle'in layoutmsg alt komutları YALNIZCA togglesplit /
    #     swapsplit / rotatesplit / movetoroot / preselect / splitratio
    #     (DwindleAlgorithm.cpp:640-733) — "cyclenext" aralarında değil;
    #   * "cycleprev" ise hiçbir dispatcher değil; v0.55.0 listesinde yalnız
    #     "cyclenext" var (KeybindManager.cpp:37-105).
    # Doğru biçim `cyclenext` dispatcher'ı: argümansız = sonraki pencere,
    # "prev" = önceki (DispatcherTranslator.cpp:471-489).
    bind = $mainMod, mouse_down, cyclenext
    bind = $mainMod, mouse_up, cyclenext prev

    # ⚠️ $mainMod + M (monocle) BİLEREK BAĞLI DEĞİL.
    # Eski satır `hyprctl dispatch layoutmsg set monocle` idi ve dwindle'da
    # "Unknown dwindle layoutmsg: set monocle" hatası veriyordu. v0.55.0'in
    # legacy dispatcher listesinde çalışma zamanında layout değiştiren hiçbir
    # komut yok; monocle yalnızca çalışma zamanı DIŞINDA, kural ile seçilir:
    #
    #     workspace = 1, layout:monocle
    #
    # (kalıcı, workspace başına) ya da hyprwm-community/workspacelayout
    # plugin'i ile. İkisi de bu config'te bilerek yok.

    bind = $mainMod SHIFT, left,  movewindow, l
    bind = $mainMod SHIFT, right, movewindow, r
    bind = $mainMod SHIFT, up,    movewindow, u
    bind = $mainMod SHIFT, down,  movewindow, d

    bind = $mainMod, left,  movefocus, l
    bind = $mainMod, right, movefocus, r
    bind = $mainMod, up,    movefocus, u
    bind = $mainMod, down,  movefocus, d

    bind = $mainMod CTRL, right, resizeactive,  40   0
    bind = $mainMod CTRL, left,  resizeactive, -40   0
    bind = $mainMod CTRL, up,    resizeactive,   0 -40
    bind = $mainMod CTRL, down,  resizeactive,   0  40

    bind = $mainMod, H, movefocus, l
    bind = $mainMod, L, movefocus, r
    bind = $mainMod, J, movefocus, d
    bind = $mainMod, K, movefocus, u

    bind = $mainMod SHIFT, H, movewindow, l
    bind = $mainMod SHIFT, L, movewindow, r
    bind = $mainMod SHIFT, J, movewindow, d
    bind = $mainMod SHIFT, K, movewindow, u

    bind = $mainMod CTRL, H, resizeactive, -50 0
    bind = $mainMod CTRL, L, resizeactive,  50 0
    bind = $mainMod CTRL, J, resizeactive,  0  50
    bind = $mainMod CTRL, K, resizeactive,  0 -50

    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, workspace, 10

    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5
    bind = $mainMod SHIFT, 6, movetoworkspace, 6
    bind = $mainMod SHIFT, 7, movetoworkspace, 7
    bind = $mainMod SHIFT, 8, movetoworkspace, 8
    bind = $mainMod SHIFT, 9, movetoworkspace, 9
    bind = $mainMod SHIFT, 0, movetoworkspace, 10

    bind = $mainMod, G, togglegroup
    bind = $mainMod, TAB, changegroupactive

    bind = $mainMod, Tab, workspace, previous

    binde = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    binde = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bind  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    bind = $mainMod SHIFT, C, exec, ${pkgs.hyprpicker}/bin/hyprpicker -a && notify-send "Renk" "$(wl-paste)" -t 2000

    bind = $mainMod SHIFT, E, exit

    # WuWa otomatik çeviri toggle (Y tuşu).
    # ESKİ HALİ: pkill -f wuwa-auto.sh || ~/.config/.../wuwa-auto.sh
    # Bu kalıp ÇALIŞMIYORDU: Hyprland exec'i "/bin/sh -c '<satır>'" ile
    # çalıştırıyor, kabuğun komut satırı "wuwa-auto.sh" metnini içeriyor ve
    # pkill -f kendi üst kabuğunu öldürüyordu → || fallback'i asla çalışmıyor,
    # tuşa basmak hiçbir şey yapmıyordu. Sandbox'ta yeniden üretildi.
    # Çözüm: ayrı bir toggle betiği. Betiğin kendi yolu "toggle-wuwa.sh"
    # olduğu için "wuwa-auto[.]sh" deseni onu EŞLEŞTİRMEZ.
    bind = $mainMod, Y, exec, ~/.config/hypr/scripts/toggle-wuwa.sh

    # Manuel OCR çeviri (SHIFT+T)
    bind = $mainMod SHIFT, T, exec, grim -g "$(slurp)" - | tesseract - stdout -l eng 2>/dev/null | trans -b :tr | notify-send -t 10000 "Çeviri" "$(cat -)"

    # Sürekli panoya-göre otomatik çeviri toggle (ALT+T) — daha önce
    # scripts/auto-translate.sh repo'da vardı ama hiçbir kısayola
    # bağlı değildi, artık gerçekten kullanılabilir.
    # Aynı pkill -f kendini-kill sorunu burada da vardı → ayrı toggle betiği.
    bind = $mainMod ALT, T, exec, ~/.config/hypr/scripts/toggle-auto-translate.sh

    # SUPER + sol/sağ tuşla sürükleme. 272/273 = BTN_LEFT / BTN_RIGHT
    # (0x110 / 0x111) — bunlar GERÇEK buton kodlarıdır, tekerlek ekseni
    # değil; onMouseEvent() (KeybindManager.cpp:438-448) onları
    # "mouse:<code>" adıyla tetikliyor. Bu iki satır ÇALIŞIYOR ve yukarıdaki
    # tekerlek binding'leriyle karışmıyor, çünkü anahtar adları farklı
    # ("mouse:272" ≠ "mouse_down") ve handleKeybinds m_keybinds'i ortak
    # haritada, yalnız ad+modmask eşleştiriyor.
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    windowrule = match:class ^(cs2)$, immediate on, fullscreen on, no_blur on, no_shadow on, no_anim on, rounding 0
    windowrule = match:class ^(gamescope|Gamescope)$, immediate on, fullscreen on, no_blur on, no_shadow on, no_anim on, rounding 0
    windowrule = match:class ^(pavucontrol)$, float on, size 500 600
    windowrule = match:class ^(nm-connection-editor)$, float on
    windowrule = match:title ^(scratchterm)$, float on, size 60% 60%

    # ÇİFT BAŞLATMA TEMİZLİĞİ:
    # mpvpaper, mpvpaper-watchdog ve gamemode-notify artık yalnızca systemd
    # user unit'lerinden başlatılıyor. Eskiden hem hyprland exec-once hem
    # systemd aynı servisi tetikliyordu (watchdog için iki instance, yarış
    # koşulu; mpvpaper ve gamemode-notify için gereksiz tekrar).
    exec-once = ${pkgs.pcmanfm}/bin/pcmanfm --desktop
    exec-once = hyprctl setcursor capitaine-cursors 16
    exec-once = waybar
    exec-once = dunst
    exec-once = wl-paste --watch cliphist store
    exec-once = nm-applet --indicator
    exec-once = ${pkgs.hyprpolkitagent}/bin/hyprpolkitagent
    exec-once = dbus-update-activation-environment --systemd DISPLAY
    exec-once = pypr
    exec-once = systemctl --user start mpvpaper-watchdog gamemode-notify
    exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
  '';

  hyprlockConf = ''
    general {
        grace = 0
        disable_loading_bar = false
    }
    background { color = rgba(0, 0, 0, 1.0) }
    label {
        position = 0, -65; size = 250, 50; halign = center; valign = center;
        text = ; font_family = JetBrainsMono Nerd Font; font_size = 15;
        color = rgba(203, 166, 247, 1.0); shadow_passes = 0;
    }
    input-field {
        position = 0, -120; size = 300, 50; halign = center; valign = center;
        placeholder_text =  Şifre...; font_family = JetBrainsMono Nerd Font; font_size = 20;
        dots_size = 0.55; dots_spacing = 0.15; check_symbol = ;
        placeholder_color = rgba(255, 255, 255, 0.4); font_color = rgba(255, 255, 255, 1.0);
        check_color = rgba(166, 227, 161, 1.0); fail_color = rgba(243, 139, 168, 1.0);
        fail_transition = 300; hide_input = false; rounding = 10;
        outline_thickness = 2; outer_color = rgba(255, 255, 255, 0.1);
        inner_color = rgba(0, 0, 0, 0.9); shadow_passes = 0;
    }
    label {
        position = 0, 150; size = 500, 100; halign = center; valign = center;
        text =  {H:M}; font_family = JetBrainsMono Nerd Font; font_size = 80;
        font_color = rgba(255, 255, 255, 1.0); shadow_passes = 0;
    }
    label {
        position = 0, 60; size = 500, 50; halign = center; valign = center;
        text = cmd[update:60000, LC_TIME=tr_TR.UTF-8 date +"%d %B %Y"];
        font_family = JetBrainsMono Nerd Font; font_size = 20;
        font_color = rgba(255, 255, 255, 0.6); shadow_passes = 0;
    }
    label {
        position = 0, 10; size = 500, 50; halign = center; valign = center;
        text =  {user}; font_family = JetBrainsMono Nerd Font; font_size = 15;
        font_color = rgba(255, 255, 255, 0.4); shadow_passes = 0;
    }
    label {
        position = 20, 20; size = 200, 50; halign = left; valign = top;
        text = cmd[update:2000, wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f%%", $2*100}'];
        font_family = JetBrainsMono Nerd Font; font_size = 15;
        font_color = rgba(249, 226, 175, 1.0); shadow_passes = 0;
    }
    label {
        position = 20, 20; size = 200, 50; halign = right; valign = top;
        text = cmd[update:5000, nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null | grep -v loopback | head -1 | cut -d: -f1 | xargs -I{} echo " {}" || echo " Bağlı Değil"];
        font_family = JetBrainsMono Nerd Font; font_size = 15;
        font_color = rgba(148, 226, 213, 1.0); shadow_passes = 0;
    }
    button {
        position = -20, -20; size = 50, 50; halign = right; valign = bottom;
        font_family = JetBrainsMono Nerd Font; font_size = 20;
        text = ⏻; on_click = wlogout;
        font_color = rgba(243, 139, 168, 1.0); rounding = 10;
        outline_thickness = 2; outer_color = rgba(243, 139, 168, 0.3);
    }
    button {
        position = -80, -20; size = 50, 50; halign = right; valign = bottom;
        font_family = JetBrainsMono Nerd Font; font_size = 20;
        text = 💤; on_click = systemctl suspend;
        font_color = rgba(255, 255, 255, 0.8); rounding = 10;
        outline_thickness = 2; outer_color = rgba(255, 255, 255, 0.2);
    }
  '';

  waybarStyle = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 12px; font-weight: 500; min-height: 0;
    }
    #waybar { background: #000000; color: #ffffff; border-bottom: 1px solid #222222; }
    tooltip { background: #0a0a0a; border: 1px solid #cba6f7; border-radius: 8px; }
    tooltip label { color: #ffffff; padding: 2px 6px; font-size: 11px; }
    #workspaces { background: #0a0a0a; border-radius: 10px; margin: 4px 6px; padding: 0 4px; }
    #workspaces button {
      color: #888888; background: transparent; border: none;
      border-radius: 8px; padding: 4px 10px; margin: 3px 2px; font-weight: 600;
    }
    #workspaces button.active { color: #000000; background: #cba6f7; }
    #workspaces button:hover { color: #ffffff; background: #222222; }
    #window { color: #aaaaaa; padding: 4px 12px; font-style: italic; font-size: 11px; }
    #clock {
      font-size: 13px; font-weight: 600; color: #ffffff;
      background: #0a0a0a; padding: 4px 14px; border-radius: 10px; margin: 4px;
    }
    #cpu, #memory, #temperature, #pulseaudio, #network, #gamemode, #battery, #tray, #custom-temperature {
      padding: 4px 10px; margin: 4px 3px; border-radius: 10px; background: #0a0a0a;
    }
    #cpu.warning { color: #f9e2af; }
    #cpu.critical { color: #f38ba8; }
    #memory.warning { color: #f9e2af; }
    #memory.critical { color: #f38ba8; }
    #mpris { background: #111111; color: #cba6f7; border-radius: 10px; padding: 4px 10px; margin: 4px 3px; }
    #mpris.playing { color: #a6e3a1; }
    #mpris.paused  { color: #f9e2af; }
    #mpris.stopped { color: #6c7086; }
    #cpu { color: #89b4fa; }
    #memory { color: #a6e3a1; }
    #custom-temperature { color: #fab387; }
    #pulseaudio { color: #f9e2af; }
    #network { color: #94e2d5; }
    #gamemode { color: #cba6f7; font-weight: bold; }
    #battery { color: #a6e3a1; }
    #custom-power {
      color: #f38ba8; font-size: 15px; font-weight: bold;
      padding: 4px 12px; margin: 4px; background: #0a0a0a; border-radius: 10px;
    }
    #custom-power:hover { background: #222222; }
  '';

  waybarConfig = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 32;
    spacing = 4;
    margin-top = 0;
    margin-bottom = 0;
    modules-left = [ "hyprland/workspaces" "hyprland/window" ];
    modules-center = [ "clock" ];
    modules-right = [
      "mpris" "gamemode" "cpu" "memory"
      "custom/temperature" "pulseaudio" "network" "tray" "custom/power"
    ];

    "hyprland/workspaces" = {
      format = "{name}";
      format-icons = {
        "1" = "一"; "2" = "二"; "3" = "三"; "4" = "四"; "5" = "五";
        "6" = "六"; "7" = "七"; "8" = "八";
        urgent = "！"; active = "●"; default = "○";
      };
      on-click = "activate";
      all-outputs = false;
      show-special = false;
      persistent-workspaces = { "1" = []; "2" = []; "3" = []; };
    };

    "hyprland/window" = {
      format = "{}";
      max-length = 50;
      rewrite = {
        "(.*) - Brave" = "🌐 $1";
        "(.*) — Dolphin" = "📁 $1";
        "kitty" = "🐱 kitty";
      };
    };

    gamemode = {
      format = "{glyph}";
      format-alt = "{glyph} {count}";
      glyph = "🎮";
      hide-not-running = true;
      use-icon = true;
      icon-name = "input-gaming-symbolic";
      icon-spacing = 4;
      icon-size = 16;
      tooltip = true;
      tooltip-format = "GameMode aktif: {count} oyun";
    };

    cpu = {
      interval = 5;
      format = " {usage}% {icon}";
      format-icons = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
      format-alt = "⚡ {usage}%";
      tooltip = true;
      tooltip-format = "CPU kullanımı: {usage}%\nFrequency: {frequency} GHz";
      on-click = "kitty -e btop";
      states = { warning = 70; critical = 90; };
    };

    memory = {
      interval = 10;
      format = " {}%";
      format-alt = "🧠 {used:0.1f}G / {total:0.1f}G";
      tooltip = true;
      tooltip-format = "Kullanılan: {used:0.1f} GiB\nToplam: {total:0.1f} GiB\nBoş: {avail:0.1f} GiB";
      on-click = "kitty -e btop";
      states = { warning = 70; critical = 90; };
    };

    "custom/temperature" = {
      exec = "${config.home.homeDirectory}/.local/bin/waybar-temperature.sh";
      return-type = "json";
      interval = 5;
      on-click = "kitty -e btop";
      tooltip = false;
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "🔇";
      format-bluetooth = "󰂯 {volume}%";
      format-bluetooth-muted = "󰂯";
      format-icons = {
        headphone = ""; hands-free = "󰂰"; headset = "󰂰";
        phone = ""; portable = ""; car = "";
        default = ["🔈" "🔉" "🔊"];
      };
      on-click = "pavucontrol";
      on-click-right = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      on-scroll-up = "pactl set-sink-volume @DEFAULT_SINK@ +5%";
      on-scroll-down = "pactl set-sink-volume @DEFAULT_SINK@ -5%";
      tooltip = true;
      tooltip-format = "Ses: {volume}%\nÇıkış: {desc}";
      states = { muted = 0; };
    };

    network = {
      interval = 10;
      format-wifi = "📶 {signalStrength}%";
      format-ethernet = "🌐 {ipaddr}";
      format-disconnected = "⚠️ Bağlı Değil";
      format-linked = "🌐 (No IP)";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\nIP: {ipaddr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
      tooltip-format-ethernet = "Ethernet\nIP: {ipaddr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
      tooltip-format-disconnected = "Bağlantı yok";
      on-click = "nm-connection-editor";
    };

    clock = {
      interval = 60;
      format = " {:%H:%M}";
      format-alt = "📅 {:%d/%m/%Y %H:%M}";
      tooltip-format = "<big>{:%Y %B}</big>\n{calendar}";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        weeks-pos = "right";
        on-scroll = 1;
        on-click-right = "mode";
        format = {
          months = "<span color='#cdd6f4'><b>{}</b></span>";
          days = "<span color='#cdd6f4'>{}</span>";
          weeks = "<span color='#a6e3a1'><b>H{}</b></span>";
          weekdays = "<span color='#f9e2af'><b>{}</b></span>";
          today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
        };
      };
      timezone = "Europe/Istanbul";
    };

    tray = { icon-size = 16; spacing = 8; show-passive-icons = true; };

    mpris = {
      player = ["spotify" "spotifyd" "com.spotify.Client" "firefox" "chromium" "brave-browser"];
      format = "{player_icon} {artist} - {title}";
      format-paused = "⏸ {artist} - {title}";
      format-stopped = "";
      player-icons = { default = "🎵"; spotify = ""; firefox = "🦊"; chromium = ""; };
      status-icons = { paused = "⏸"; playing = "▶"; stopped = "■"; };
      max-length = 40;
      on-click = "playerctl play-pause";
      on-click-right = "playerctl stop";
      tooltip-format = "{player}\n{status}\n{artist} — {album}\n{title}";
    };

    "custom/power" = {
      format = "⏻";
      tooltip = true;
      tooltip-format = "Güç Menüsü\nSol: wlogout\nSağ: Kapat";
      on-click = "wlogout";
      on-click-right = "systemctl poweroff";
    };
  };
in
{
  home.username = "localhost";
  home.homeDirectory = "/home/localhost";
  home.stateVersion = "26.05";

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-Mocha";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "mauve" ];
        size = "compact";
        tweaks = [ "rimless" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "capitaine-cursors";
      package = pkgs.capitaine-cursors;
      size = 16;
    };
    gtk3.extraCss = gtkCss;
    gtk4.extraCss = gtkCss;
  };

  xdg.configFile = {
    "hypr/hyprland.conf".text = hyprlandConf;
    "hypr/hyprlock.conf".text = hyprlockConf;
    "waybar/style.css".text = waybarStyle;
    "waybar/config.jsonc".text = waybarConfig;

    # ── Toggle betikleri (P0-6) ──────────────────────────────────────
    # Hyprland exec'i "/bin/sh -c '<satır>'" ile çalıştırır. Satırın İÇİNDE
    # "pkill -f wuwa-auto.sh || …/wuwa-auto.sh" yazılıydı; pkill -f komut
    # satırının tamamını aradığı için kendi üst kabuğunu öldürüyor, || fallback'i
    # hiç çalışmıyor ve tuş hiçbir şey yapmıyordu.
    # Ayrı betiğe taşınca sorun yok: betiğin kendi yolu "toggle-wuwa.sh" olduğu
    # için "wuwa-auto[.]sh" deseni onu eşleştirmiyor.
    # Bu desen sandbox'ta T1/T2/T3 olarak test edildi: başlatıyor, durduruyor ve
    # sh -c üzerinden (Hyprland'ın gerçek çağrı yolu) de çalışıyor.
    "hypr/scripts/toggle-wuwa.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if pgrep -f "hypr/scripts/wuwa-auto[.]sh" >/dev/null 2>&1; then
          pkill -f "hypr/scripts/wuwa-auto[.]sh"
          notify-send "WuWa AI" "Durduruldu" -t 2000
        else
          exec "$HOME/.config/hypr/scripts/wuwa-auto.sh"
        fi
      '';
    };

    "hypr/scripts/toggle-auto-translate.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if pgrep -f "hypr/scripts/auto-translate[.]sh" >/dev/null 2>&1; then
          pkill -f "hypr/scripts/auto-translate[.]sh"
          notify-send "Otomatik Çeviri" "Durduruldu" -t 2000
        else
          exec "$HOME/.config/hypr/scripts/auto-translate.sh"
        fi
      '';
    };

    # ── Daha önce hiçbir yere deploy edilmeyen dosyalar ───────────────
    # MangoHud.conf ve conf.toml (lsfg-vk) repoda duruyordu ama hiçbir modül
    # onları kullanmıyordu; oyunlarda o ayarlar hiç uygulanmıyordu.
    "MangoHud/MangoHud.conf".text = ''
      ###############################
      # MangoHud - Catppuccin Mocha
      ###############################

      frame_timing=1
      fps=1
      frametime=1
      gpu_stats=1
      cpu_stats=1
      gpu_temp=1
      cpu_temp=1
      gpu_vram=1
      ram=1

      fps_format="FPS: {fps}"
      frametime_format="FT: {frametime}"
      gpu_format="GPU: {gpu} {gpu_temp}°C"
      cpu_format="CPU: {cpu} {cpu_temp}°C"
      vram_format="VRAM: {vram}"
      ram_format="RAM: {ram}"

      position=top-left
      offset_x=10
      offset_y=10

      background_alpha=0.6
      background_color=1E1E2E
      text_color=CDD6F4
      fps_color=CDD6F4
      frametime_color=F9E2AF
      gpu_color=89B4FA
      cpu_color=FAB387
      vram_color=A6E3A1
      ram_color=A6E3A1
      temperature_color=F38BA8

      font_size=20

      legacy_layout=false
      io_read=0
      io_write=0
      battery=0
      network=0

      gpu_text=GPU
      cpu_text=CPU
      vram_text=VRAM
      ram_text=RAM
    '';

    "lsfg-vk/conf.toml".text = ''
      version = 1

      [global]

      # Oyun başına kare üretim çarpanı. exe alanı süreç adıyla eşleşir.
      # (Eski değerde "Genshin" yazıyordu; süreç adı GenshinImpact.)
      [[game]]
      exe = "GenshinImpact"
      multiplier = 3
      flow_scale = 1.0
      performance_mode = false
      hdr_mode = false
      experimental_present_mode = "fifo"

      [[game]]
      exe = "benchmark"
      multiplier = 4
      flow_scale = 1.0
      performance_mode = false
      hdr_mode = false
      experimental_present_mode = "fifo"

      [[game]]
      exe = "cs2"
      multiplier = 2
      flow_scale = 0.75
      performance_mode = false
      hdr_mode = true
      experimental_present_mode = "fifo"

      [[game]]
      exe = "vkcube"
      multiplier = 4
      flow_scale = 1.0
      performance_mode = true
      hdr_mode = false
      experimental_present_mode = "fifo"

      [[game]]
      exe = "wuwa"
      multiplier = 2
      flow_scale = 0.9
      performance_mode = false
      hdr_mode = true
      experimental_present_mode = "fifo"
    '';

    # pyprland kurulu ama config'i yoktu; hyprland.conf'taki
    # "pypr toggle term/music/filemanager" bağlantıları tanımsızdı.
    #
    # pyprland 3.4.4 (kök nixpkgs rev'i 7a0f122f5090) üç yol tanıyor
    # (src/constants.py:45-47):
    #   CONFIG_FILE        = ~/.config/pypr/config.toml     ← KANONİK
    #   LEGACY_CONFIG_FILE = ~/.config/hypr/pyprland.toml  ← ESKİ
    #   OLD_CONFIG_FILE    = ~/.config/hypr/pyprland.json   ← çok eski
    # Daha önce LEGACY yola yazılıyordu. Önceki yorum "pypr/config.toml
    # pyprland tarafından okunmaz" diyordu; bu TERSİNE DOĞRUYDU — okunan
    # legacy yoldu. Legacy dosya yine de okunur, ama her açılışta
    # "Config at legacy location. Move to: …/pypr/config.toml" uyarısı
    # basılır ve ekranda migration bildirimi gösterilir
    # (src/config_loader.py:173-185). Artık kanonik yola yazılıyor.
    #
    # Bölüm formatı:
    #   [pyprland] plugins = [...]  +  [scratchpads.<ad>]
    # [[pypr.apps]] / useOn / [pypr] pyprland tarafından hiç okunmaz.
    "pypr/config.toml".text = ''
      [pyprland]
      plugins = [ "scratchpads" ]

      # hyprland.conf: bind = $mainMod, S, exec, pypr toggle term
      [scratchpads.term]
      animation = "fromTop"
      command = "kitty --class pypr-term"
      class = "pypr-term"
      size = "70% 60%"
      margin = 50

      # bind = $mainMod SHIFT, S, exec, pypr toggle music
      # playerctl'ın pencereesi yok; bu bir medya oynatıcı (mpv, zaten kurulu).
      # Farklı bir oynatıcı isterseniz command/class değerlerini değiştirin.
      [scratchpads.music]
      animation = "fromRight"
      command = "mpv --class pypr-music --no-config --idle"
      class = "pypr-music"
      size = "45% 70%"
      unfocus = "hide"
      lazy = true

      # bind = $mainMod CTRL, S, exec, pypr toggle filemanager
      [scratchpads.filemanager]
      animation = "fromRight"
      command = "pcmanfm"
      class = "pcmanfm"
      size = "60% 70%"
      lazy = true
    '';

    # Bu iki script daha önce ../.config/hypr/scripts/*.sh şeklinde repo
    # köküne göreli bir "source" yolu ile deploy ediliyordu. install.sh ise
    # /etc/nixos altına sadece configuration.nix/home.nix/flake*/hooks
    # dosyalarını kopyalıyor, .config/ dizinini KOPYALAMIYOR — bu yüzden
    # install.sh ile kurulan bir sistemde bu göreli yol
    # (/etc/.config/hypr/scripts/...) hiç var olmuyordu ve nixos-rebuild
    # "path does not exist" hatasıyla patlıyordu. Harici bir dosyaya
    # bağımlı olmamak için script içerikleri artık doğrudan burada,
    # inline metin olarak gömülü — home.nix nereye kopyalanırsa
    # kopyalansın çalışır.
    "hypr/scripts/wuwa-auto.sh" = {
      executable = true;
      text = ''
#!${pkgs.bash}/bin/bash

# ─── Yeni bölge tanımları (Senin jilet gibi hassas koordinatların) ───
GEOMETRY_MAIN="0,971 2560x438"
GEOMETRY_CHOICE="1561,513 916x585"

IMAGE_MAIN="/tmp/wuwa_main.png"
IMAGE_CHOICE="/tmp/wuwa_choice.png"

LAST_MAIN=""
LAST_CHOICE=""

# ─── Tesseract en iyi model dizini ───
TESSDATA_DIR="$HOME/.local/share/tessdata"

# Eğer dizin yoksa Tesseract'ın sistemdeki ana yoluna düşmesi için bir kontrol
[ ! -d "$TESSDATA_DIR" ] && TESSDATA_DIR="/run/current-system/sw/share/tessdata"

# ─── Çeviri önbelleği ───
CACHE_FILE="/tmp/wuwa_translate_cache"
touch "$CACHE_FILE"

# ─── Hızlı çeviri (Argos Translate) ───
translate_fast() {
    echo "$1" | argos-translate --from-lang en --to-lang tr 2>/dev/null
}

# ─── Yedek çeviri (Ollama LLM - Güvenli JSON formatı ile) ───
translate_llm() {
    local text="$1"
    # jq kullanarak girdiyi güvenli bir şekilde JSON stringine çeviriyoruz, asla patlamaz
    local json_payload
    json_payload=$(jq -n --arg mod "wuwa-gemma" --arg pr "EN: $text\nTR:" '{model: $mod, prompt: $pr, stream: false, options: {temperature: 0.0, num_predict: 80}}')

    curl -s http://localhost:11434/api/generate -d "$json_payload" | jq -r '.response' 2>/dev/null | xargs
}

# ─── Genel çeviri (önbellek + Argos → Ollama) ───
translate() {
    local raw="$1"
    local letter_count=$(echo "$raw" | tr -cd 'a-zA-Z' | wc -c)
    [ "$letter_count" -lt 5 ] && { echo ""; return; }

    # Önbellek kontrolü
    local cached=$(grep -F "$raw" "$CACHE_FILE" | head -n 1 | cut -d'|' -f2)
    [ -n "$cached" ] && { echo "$cached"; return; }

    # Hızlı çeviriyi dene
    local fast=$(translate_fast "$raw")
    if [ -n "$fast" ] && [ "''${#fast}" -gt 2 ]; then
        echo "$raw|$fast" >> "$CACHE_FILE"
        echo "$fast"
        return
    fi

    # Yedek olarak LLM'ye (Aya/Gemma) sor
    local llm=$(translate_llm "$raw")
    if [ -n "$llm" ]; then
        echo "$raw|$llm" >> "$CACHE_FILE"
        echo "$llm"
        return
    fi
}

# ─── Ana döngü ───
while true; do
    # 1. Ana altyazı
    grim -g "$GEOMETRY_MAIN" "$IMAGE_MAIN" 2>/dev/null
    mogrify -resize 200% \
            -modulate 100,0 \
            -colorspace Gray \
            -lat 20x20+5% \
            -negate \
            -sharpen 0x2 \
            "$IMAGE_MAIN" 2>/dev/null

    RAW_MAIN=$(tesseract "$IMAGE_MAIN" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
    TEXT_MAIN=$(echo "$RAW_MAIN" | tr -d '\f' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

    if [ ''${#TEXT_MAIN} -gt 5 ]; then
        if [ "$TEXT_MAIN" != "$LAST_MAIN" ]; then
            LAST_MAIN="$TEXT_MAIN"
            TRANSLATION_MAIN=$(translate "$TEXT_MAIN")
            [ -n "$TRANSLATION_MAIN" ] && notify-send -r 9999 "💬 Wuwa AI (Altyazı)" "$TRANSLATION_MAIN"
        fi
    else
        [ -n "$LAST_MAIN" ] && { LAST_MAIN=""; pkill -f "notify-send -r 9999"; }
    fi
    rm -f "$IMAGE_MAIN" 2>/dev/null

    # 2. Seçenek/cevap alanı
    grim -g "$GEOMETRY_CHOICE" "$IMAGE_CHOICE" 2>/dev/null
    mogrify -resize 200% \
            -modulate 100,0 \
            -colorspace Gray \
            -lat 20x20+5% \
            -negate \
            -sharpen 0x2 \
            "$IMAGE_CHOICE" 2>/dev/null

    RAW_CHOICE=$(tesseract "$IMAGE_CHOICE" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
    TEXT_CHOICE=$(echo "$RAW_CHOICE" | tr -d '\f' | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

    if [ ''${#TEXT_CHOICE} -gt 5 ]; then
        if [ "$TEXT_CHOICE" != "$LAST_CHOICE" ]; then
            LAST_CHOICE="$TEXT_CHOICE"
            TRANSLATION_CHOICE=$(translate "$TEXT_CHOICE")
            [ -n "$TRANSLATION_CHOICE" ] && notify-send -r 9998 "💡 Wuwa AI (Seçenekler)" "$TRANSLATION_CHOICE"
        fi
    else
        [ -n "$LAST_CHOICE" ] && { LAST_CHOICE=""; pkill -f "notify-send -r 9998"; }
    fi
    rm -f "$IMAGE_CHOICE" 2>/dev/null

    sleep 3
done
'';
    };
    "hypr/scripts/auto-translate.sh" = {
      executable = true;
      text = ''
#!${pkgs.bash}/bin/bash

# Önceki seçimi hafızada tutmak için değişken
LAST_SELECTION=""

echo "Anlık çeviri modu aktif... Seçtiğiniz metinler otomatik çevrilecek."

# wl-paste --watch yerine primary selection'ı (farenin seçtiği metni) 
# sürekli kontrol eden hafif bir döngü kuruyoruz.
while true; do
    # Fareyle seçilen güncel metni al
    CURRENT_SELECTION=$(wl-paste -p 2>/dev/null)

    # Eğer seçim boş değilse ve bir önceki seçimden farklıysa işlem yap
    if [ -n "$CURRENT_SELECTION" ] && [ "$CURRENT_SELECTION" != "$LAST_SELECTION" ]; then
        LAST_SELECTION="$CURRENT_SELECTION"
        
        # Seçilen metni translate-shell ile hızlıca Türkçeye çevir (:tr)
        # Sadece çeviriyi almak için -b (brief) modunu kullanıyoruz
        TRANSLATION=$(trans -b :tr "$CURRENT_SELECTION" 2>/dev/null)

        # Eğer çeviri başarılıysa Dunst vasıtasıyla ekranda göster
        if [ -n "$TRANSLATION" ]; then
            # -r 9999 parametresi bildirimlerin üst üste binmesini engeller, sürekli günceller
            notify-send -r 9999 "Çeviri:" "$TRANSLATION"
        fi
    fi
    # İşlemciyi yormamak için her yarım saniyede bir kontrol et
    sleep 0.5
done
'';
    };
  };

  home.file.".local/bin/waybar-temperature.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      temp=""
      for hwmon in /sys/class/hwmon/hwmon*; do
        if [ -e "$hwmon/name" ]; then
          name=$(cat "$hwmon/name")
          if [ "$name" = "amdgpu" ]; then
            for label_file in "$hwmon"/temp*_label; do
              [ -e "$label_file" ] || continue
              label=$(cat "$label_file")
              if [ "$label" = "junction" ]; then
                input_file="''${label_file%_label}_input"
                raw=$(cat "$input_file" 2>/dev/null)
                [ -n "$raw" ] && temp=$((raw / 1000))
                break 2
              fi
            done
            if [ -z "$temp" ]; then
              for input in "$hwmon"/temp*_input; do
                [ -e "$input" ] && { raw=$(cat "$input"); temp=$((raw / 1000)); break; }
              done
            fi
            break
          fi
        fi
      done
      if [ -z "$temp" ]; then
        raw=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
        [ -n "$raw" ] && temp=$((raw / 1000))
      fi
      if [ -n "$temp" ]; then
        echo "{\"text\": \"🌡️ $temp°C\", \"class\": \"normal\"}"
      else
        echo "{\"text\": \"🌡️ N/A\", \"class\": \"error\"}"
      fi
    '';
  };

  # mpvpaper watchdog (BindsTo kaldırıldı)
  home.file.".local/bin/mpvpaper-watchdog" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      MONITORED_CLASSES="brave-browser"
      HYPR_SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      is_gamemode_active() {
        local count
        count=$(busctl --user get-property com.feralinteractive.GameMode \
          /com/feralinteractive/GameMode com.feralinteractive.GameMode ClientCount \
          2>/dev/null | awk '{print $2}')
        [ -n "$count" ] && [ "$count" -gt 0 ]
      }

      count_monitored() {
        hyprctl clients -j | jq -r --arg classes "$MONITORED_CLASSES" \
          '[.[].class | select(. != null)] | map(select(. as $c | $classes | split(",") | index($c))) | length'
      }

      update_wallpaper() {
        if [ "$(count_monitored)" -gt 0 ]; then
          systemctl --user stop mpvpaper.service 2>/dev/null
        else
          if is_gamemode_active; then
            systemctl --user stop mpvpaper.service 2>/dev/null
          else
            systemctl --user start mpvpaper.service 2>/dev/null
          fi
        fi
      }

      update_wallpaper

      if [ -S "$HYPR_SOCK" ]; then
        socat -u "UNIX-CONNECT:$HYPR_SOCK" - | while read -r line; do
          case "$line" in
            openwindow*|closewindow*|activewindowv2*)
              update_wallpaper
              ;;
          esac
        done
      else
        echo "Hyprland socket bulunamadı" >&2
        exit 1
      fi
    '';
  };

  # home.persistence anahtarı DOĞRUDAN kalıcı depolama kök yoludur:
  # impermanence HM modülünde persistentStoragePath'in varsayılanı anahtarın
  # kendisidir, yani "/nix/persist/home" gerçek köktür. $HOME'a GÖRE yorumlanmaz.
  # (Anahtarın mutlak yol olmak zorunda olmasının nedeni modülün tip
  #  kısıtıdır — göreli yol verilirse eval "not of type 'absolute path'"
  #  hatasıyla düşüyor; gerçek eval ile doğrulandı.)
  # ⚠️ Burada yalnızca lsfg-vk shader önbelleği korunuyor. /nix/persist'in
  # kendisi bu tanımla yönetilmez (impermanence'in "nix" manager'ı bu modül
  # NixOS tarafında, home.persistence tanımı ona dokunmaz).
  home.persistence."/nix/persist/home" = {
    directories = [ ".config/lsfg-vk" ];
  };

  programs = {
    home-manager.enable = true;

    fish = {
      enable = true;
      shellAliases = {
        ll = "eza -la --icons";
        la = "eza -a --icons";
        l = "eza -lah --icons";
        cat = "bat";
        nrs = "sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos";
        nup = "nix flake update";
        nclean = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
        ntest = "sudo nixos-rebuild dry-activate --flake /etc/nixos/nixos#nixos";
        lock = "hyprlock";
        suspend = "systemctl suspend";
        reboot = "systemctl reboot";
        shutdown = "systemctl poweroff";
        snap-root = "sudo snapper -c root list";
        snap-home = "sudo snapper -c home list";
        snap-diff = "sudo snapper -c root diff";
        btrfs-df = "sudo btrfs filesystem df /";
        btrfs-cmp = "sudo compsize -x /";
        gm-status = "gamemoded -s";
      };
      interactiveShellInit = ''
        set -gx MANPAGER 'sh -c "col -bx | bat -l man -p --paging=always"'
      '';
      shellInit = ''
        set -gx fish_greeting ""
      '';
    };

    starship = {
      enable = true;
      settings = {
        format = "$directory$git_branch$git_status$character";
        right_format = "$cmd_duration$time";
        add_newline = false;
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol   = "[❯](bold red)";
        };
        directory = {
          style = "bold cyan";
          truncation_length = 3;
          truncate_to_repo = false;
        };
        git_branch = {
          symbol = " ";
          style  = "bold purple";
        };
        git_status.style = "bold yellow";
        cmd_duration = {
          min_time = 2000;
          style    = "bold yellow";
          format   = "[$duration]($style) ";
        };
        time = {
          disabled = false;
          format   = "[$time]($style) ";
          style    = "bold dimmed white";
          time_format = "%H:%M";
        };
      };
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
    };

    fzf = {
      enable = true;
      enableFishIntegration = true;
      defaultOptions = [
        "--height 40%"
        "--border"
        "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
        "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
        "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
      ];
    };

    eza = {
      enable = true;
      enableFishIntegration = true;
      git = true;
      icons = "auto";
    };

    bat = {
      enable = true;
      config = {
        theme = "Catppuccin Mocha";
        style = "numbers,changes,header";
      };
    };

    git = {
      enable = true;
      settings = {
        user.name = gitName;
        user.email = gitEmail;
        core.editor = "nano";
        core.autocrlf = "input";
        pull.rebase = false;
        push.default = "simple";
        init.defaultBranch = "main";
        diff.colorMoved = "default";
      };
    };

    htop.enable = true;
    htop.settings = {
      color_scheme = 0;
      show_cpu_frequency = 1;
      show_program_path = 0;
      highlight_base_name = 1;
      tree_view = 1;
    };

    btop = {
      enable = true;
      settings = {
        color_theme = "catppuccin_mocha";
        theme_background = false;
        truecolor = true;
        vim_keys = true;
        update_ms = 1000;
        proc_sorting = "cpu lazy";
        proc_tree = false;
        cpu_graph_upper = "total";
        mem_graphs = true;
        show_gpu_info = "Auto";
      };
    };

    kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };
      settings = {
        foreground = "#ffffff";
        background = "#000000";
        selection_foreground = "#000000";
        selection_background = "#cba6f7";
        cursor = "#cba6f7";
        cursor_text_color = "#000000";
        url_color = "#cba6f7";
        active_tab_foreground = "#000000";
        active_tab_background = "#cba6f7";
        inactive_tab_foreground = "#ffffff";
        inactive_tab_background = "#111111";
        color0  = "#45475a"; color1  = "#f38ba8";
        color2  = "#a6e3a1"; color3  = "#f9e2af";
        color4  = "#89b4fa"; color5  = "#f5c2e7";
        color6  = "#94e2d5"; color7  = "#bac2de";
        color8  = "#585b70"; color9  = "#f38ba8";
        color10 = "#a6e3a1"; color11 = "#f9e2af";
        color12 = "#89b4fa"; color13 = "#f5c2e7";
        color14 = "#94e2d5"; color15 = "#a6adc8";
        window_padding_width = 10;
        cursor_shape = "beam";
        cursor_blink_interval = "0.5";
        scrollback_lines = 10000;
        repaint_delay = 10;
        input_delay = 3;
        background_opacity = "1.0";
        tab_bar_edge = "bottom";
        tab_bar_style = "fade";
        enable_audio_bell = false;
        visual_bell_duration = "0.1";
        remember_window_size = false;
        initial_window_width = "1200";
        initial_window_height = "750";
      };
    };
  };

  services.hypridle = {
  enable = true;
  settings = {
    general = {
      before_sleep_cmd = "${pkgs.hyprlock}/bin/hyprlock";
      after_sleep_cmd = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      lock_cmd = "${pkgs.hyprlock}/bin/hyprlock";
      ignore_dbus_inhibit = false;
    };
    listener = [
      {
        timeout = 300;
        on-timeout = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
        on-resume = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
      }
      {
        timeout = 150;
        on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 70%";
        on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
      }
      {
        timeout = 600;
        on-timeout = "${pkgs.hyprlock}/bin/hyprlock";
      }
      {
        # ÖNEMLİ: burada hyprlock ÇAĞRILMAZ. hyprlock foreground'da
        # bloklar; kullanıcı şifre girene kadar süreç çıkmaz, dolayısıyla
        # arkasındaki `systemctl suspend` hiç çalışmazdı. Üstelik
        # general.before_sleep_cmd zaten hyprlock'ı çağırıyor, yani
        # ikinci kez kilitleme de oluyordu. Tek görevi suspend.
        timeout = 900;
        on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };
};

systemd.user.services = {
  mpvpaper = {
    Unit = {
      Description = "mpvpaper live wallpaper service (looped)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${lib.makeBinPath [ pkgs.mpvpaper pkgs.mpv ]}";
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p --mpv-options \"loop=inf\" ${monitorOutput} ${wallpaperVideo}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  mpvpaper-watchdog = {
    Unit = {
      Description = "Brave açıldığında canlı duvar kağıdını durdurur";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${lib.makeBinPath [ pkgs.hyprland pkgs.jq pkgs.socat pkgs.systemd pkgs.gawk ]}";
      ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.local/bin/mpvpaper-watchdog";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  gamemode-notify = {
    Unit = {
      Description = "Gamemode durum değişikliklerini Dunst ile bildir";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${gamemodeNotifyScript}/bin/gamemode-notify";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = "PATH=${lib.makeBinPath [ pkgs.libnotify pkgs.dbus pkgs.gnugrep pkgs.systemd pkgs.coreutils ]}";
    };
  };
};

home.packages = with pkgs; [
  fd ripgrep jq wget curl file tree
  playerctl pamixer hyprpicker wev
  nano satty socat libnotify
 ];
}

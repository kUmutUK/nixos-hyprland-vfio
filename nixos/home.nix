# home.nix — 10/10 (tüm dotfile'lar Nix ile yönetiliyor)

{ config, pkgs, lib, ... }:

let
  gtkCss = ''
    /* === colors.css (saf siyah tema) === */
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

    /* === gtk.css === */
    window,
    .background {
      background-color: @window_bg_color;
      color: @window_fg_color;
    }

    titlebar,
    headerbar {
      background-color: @headerbar_bg_color;
      color: @headerbar_fg_color;
      border-bottom: 1px solid @headerbar_border_color;
      min-height: 38px;
      padding: 0 8px;
    }

    titlebar button,
    headerbar button {
      min-height: 24px;
      min-width: 24px;
      padding: 2px;
      border-radius: 6px;
      background: transparent;
      color: @headerbar_fg_color;
    }

    titlebar button:hover,
    headerbar button:hover {
      background: alpha(@accent_color, 0.2);
    }

    button {
      background: @card_bg_color;
      color: @card_fg_color;
      border: 1px solid @headerbar_border_color;
      border-radius: 8px;
      padding: 6px 12px;
      min-height: 28px;
      transition: 0.15s;
    }

    button:hover {
      background: shade(@card_bg_color, 1.15);
    }

    button:active {
      background: shade(@card_bg_color, 0.9);
    }

    button.suggested-action {
      background: @accent_bg_color;
      color: @accent_fg_color;
      border-color: @accent_color;
    }

    button.destructive-action {
      background: @destructive_bg_color;
      color: @destructive_fg_color;
      border-color: @destructive_color;
    }

    button:disabled {
      opacity: 0.5;
    }

    entry {
      background: @view_bg_color;
      color: @view_fg_color;
      border: 1px solid @headerbar_border_color;
      border-radius: 8px;
      padding: 6px 10px;
      min-height: 28px;
    }

    entry:focus {
      border-color: @accent_color;
      box-shadow: 0 0 0 2px alpha(@accent_color, 0.3);
    }

    textview text,
    list,
    treeview,
    .view {
      background: @view_bg_color;
      color: @view_fg_color;
    }

    list row,
    treeview row {
      padding: 4px 8px;
      border-bottom: 1px solid alpha(@headerbar_border_color, 0.3);
    }

    list row:selected,
    treeview row:selected {
      background: @accent_bg_color;
      color: @accent_fg_color;
    }

    scrollbar {
      background: transparent;
      border: none;
    }

    scrollbar slider {
      background: @popover_bg_color;
      border-radius: 10px;
      min-width: 6px;
      min-height: 6px;
    }

    scrollbar slider:hover {
      background: @card_bg_color;
    }

    menu,
    popover {
      background: @popover_bg_color;
      color: @popover_fg_color;
      border: 1px solid @headerbar_border_color;
      border-radius: 10px;
      padding: 4px;
    }

    menuitem,
    modelbutton {
      padding: 6px 12px;
      border-radius: 6px;
    }

    menuitem:hover,
    modelbutton:hover {
      background: alpha(@accent_color, 0.2);
    }

    tooltip {
      background: @card_bg_color;
      color: @card_fg_color;
      border: 1px solid @headerbar_border_color;
      border-radius: 8px;
      padding: 4px 8px;
    }

    tooltip label {
      color: @card_fg_color;
    }

    paned separator {
      background: @headerbar_border_color;
      min-width: 1px;
      min-height: 1px;
    }

    infobar {
      background: @window_bg_color;
      border: 1px solid @headerbar_border_color;
      border-radius: 8px;
      margin: 4px;
      padding: 8px;
    }

    infobar.info {
      background: alpha(@accent_color, 0.1);
      border-color: @accent_color;
    }

    infobar.warning {
      background: alpha(@warning_color, 0.1);
      border-color: @warning_color;
    }

    infobar.error {
      background: alpha(@error_color, 0.1);
      border-color: @error_color;
    }

    notebook tab {
      background: @sidebar_bg_color;
      color: @sidebar_fg_color;
      padding: 6px 12px;
      border: 1px solid @sidebar_border_color;
      border-bottom: none;
      border-radius: 8px 8px 0 0;
    }

    notebook tab:checked {
      background: @window_bg_color;
      border-color: @headerbar_border_color;
    }

    progressbar trough {
      background: @view_bg_color;
      border-radius: 6px;
      min-height: 6px;
    }

    progressbar progress {
      background: @accent_bg_color;
      border-radius: 6px;
    }

    frame {
      border: 1px solid @headerbar_border_color;
      border-radius: 8px;
      padding: 4px;
    }

    switch {
      background: @popover_bg_color;
      border-radius: 12px;
      min-width: 44px;
      min-height: 24px;
      padding: 2px;
    }

    switch slider {
      background: @window_fg_color;
      border-radius: 10px;
      min-width: 20px;
      min-height: 20px;
    }

    switch:checked {
      background: @accent_bg_color;
    }

    switch:checked slider {
      background: @accent_fg_color;
    }

    checkbutton check,
    radiobutton radio {
      background: @view_bg_color;
      border: 1px solid @headerbar_border_color;
      color: @window_fg_color;
      min-width: 18px;
      min-height: 18px;
      border-radius: 4px;
      padding: 2px;
    }

    checkbutton check:checked,
    radiobutton radio:checked {
      background: @accent_bg_color;
      border-color: @accent_color;
      color: @accent_fg_color;
    }

    scale trough {
      background: @view_bg_color;
      border-radius: 6px;
      min-height: 6px;
    }

    scale highlight {
      background: @accent_bg_color;
      border-radius: 6px;
    }

    scale slider {
      background: @window_fg_color;
      border-radius: 10px;
      min-width: 16px;
      min-height: 16px;
    }

    separator {
      background: @headerbar_border_color;
      min-height: 1px;
      min-width: 1px;
    }

    entry placeholder {
      color: alpha(@window_fg_color, 0.5);
    }

    levelbar trough {
      background: @view_bg_color;
      border-radius: 4px;
      min-height: 6px;
    }

    levelbar block {
      background: @accent_bg_color;
      border-radius: 4px;
    }

    treeview expander {
      color: @window_fg_color;
    }

    calendar {
      background: @window_bg_color;
      color: @window_fg_color;
    }

    calendar:selected {
      background: @accent_bg_color;
      color: @accent_fg_color;
    }
  '';

  hyprlandConf = ''
    # ===========================================================================
    # hyprland.conf — Saf Siyah Tema + Tüm Premium Özellikler (0.54)
    # ===========================================================================

    monitor = ,preferred,auto,1

    $accent = rgba(cba6f7ff)
    $bg = rgba(000000ff)

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

        blur {
            enabled = false
        }
    }

    animations {
        enabled = true

        bezier = smoothOut, 0.25, 0.05, 0.1, 1.0
        bezier = overshot, 0.05, 0.9, 0.1, 1.1
        bezier = bounce, 0.3, 1.6, 0.6, 1.0

        animation = windowsIn,  1, 5, smoothOut, slide
        animation = windowsOut, 1, 4, smoothOut, popin 80%
        animation = fade,       1, 4, smoothOut
        animation = workspaces, 1, 5, overshot, slide
        animation = layers, 1, 4, smoothOut, fade
        animation = border, 1, 10, smoothOut
        animation = specialWorkspace, 1, 5, overshot, slidevert
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
        swallow_regex = (kitty)
    }

    cursor {
        no_hardware_cursors = false
        inactive_timeout = 3
    }

    $mainMod = SUPER

    # -- Uygulamalar --
    bind = $mainMod, A, exec, rofi -show drun -theme arthur
    bind = $mainMod, C, exec, kitty
    bind = $mainMod, Q, killactive
    bind = $mainMod, Return, exec, kitty
    bind = $mainMod, F, fullscreen
    bind = $mainMod, V, togglefloating
    bind = $mainMod, P, exec, grim -g "$(slurp)" - | wl-copy
    bind = $mainMod, L, exec, hyprlock
    bind = $mainMod, W, exec, waypaper

    # Scratchpad
    bind = $mainMod, S, exec, pypr toggle term
    bind = $mainMod SHIFT, S, exec, pypr toggle music
    bind = $mainMod CTRL, S, exec, pypr toggle filemanager

    bind = $mainMod, M, exec, hyprctl dispatch layoutmsg set monocle
    bind = $mainMod, scroll:down, layoutmsg, cyclenext scroll
    bind = $mainMod, scroll:up, layoutmsg, cycleprev scroll

    # Pencere yerleştirme
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

    # VIM tarzı HJKL
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

    # Çalışma alanları
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

    bind = $mainMod, Tab, workspace, previous

    # Ses tuşları
    binde = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    binde = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bind  = , XF86AudioMute,        exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    bind = $mainMod SHIFT, E, exit

    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Pencere kuralları
    windowrule = match:class ^(cs2)$, immediate on, fullscreen on, no_blur on, no_shadow on, no_anim on, rounding 0
    windowrule = match:class ^(gamescope|Gamescope)$, immediate on, fullscreen on, no_blur on, no_shadow on, no_anim on, rounding 0
    windowrule = match:class ^(pavucontrol)$, float on, size 500 600
    windowrule = match:class ^(nm-connection-editor)$, float on
    windowrule = match:title ^(scratchterm)$, float on, size 60% 60%

    exec-once = systemctl --user start mpvpaper.service
    exec-once = hyprctl setcursor capitaine-cursors 16
    exec-once = waybar
    exec-once = dunst
    exec-once = wl-paste --watch cliphist store
    exec-once = nm-applet --indicator
    exec-once = hyprpolkitagent
    exec-once = dbus-update-activation-environment --systemd DISPLAY
    exec-once = pypr
  '';

  hyprlockConf = ''
    # =============================================================================
    # Hyprlock Yapılandırması - AMD RX 6700 XT + Saf Siyah Tema
    # =============================================================================

    general {
        grace = 0
        disable_loading_bar = false
    }

    # Saf siyah arka plan
    background {
        color = rgba(0, 0, 0, 1.0)
    }

    # Hatalı giriş mesajı
    auth-msg {
        position = 0, -200
        size = 400, 50
        halign = center
        valign = center
        font_family = JetBrainsMono Nerd Font
        font_size = 14
        font_color = rgba(243, 139, 168, 1.0)
        shadow_passes = 0
    }

    label {
        position = 0, -65
        size = 250, 50
        halign = center
        valign = center
        text = 
        font_family = JetBrainsMono Nerd Font
        font_size = 15
        color = rgba(203, 166, 247, 1.0)
        shadow_passes = 0
    }

    input-field {
        position = 0, -120
        size = 300, 50
        halign = center
        valign = center
        placeholder_text =  Şifre...
        font_family = JetBrainsMono Nerd Font
        font_size = 20
        dots_size = 0.55
        dots_spacing = 0.15
        check_symbol = 
        placeholder_color = rgba(255, 255, 255, 0.4)
        font_color = rgba(255, 255, 255, 1.0)
        check_color = rgba(166, 227, 161, 1.0)
        fail_color  = rgba(243, 139, 168, 1.0)
        fail_transition = 300
        hide_input = false
        rounding = 10
        outline_thickness = 2
        outer_color = rgba(255, 255, 255, 0.1)
        inner_color = rgba(0, 0, 0, 0.9)
        shadow_passes = 0
    }

    label {
        position = 0, 150
        size = 500, 100
        halign = center
        valign = center
        text =  {H:M}
        font_family = JetBrainsMono Nerd Font
        font_size = 80
        font_color = rgba(255, 255, 255, 1.0)
        shadow_passes = 0
    }

    label {
        position = 0, 60
        size = 500, 50
        halign = center
        valign = center
        text = cmd[update:60000, LC_TIME=tr_TR.UTF-8 date +"%d %B %Y"]
        font_family = JetBrainsMono Nerd Font
        font_size = 20
        font_color = rgba(255, 255, 255, 0.6)
        shadow_passes = 0
    }

    label {
        position = 0, 10
        size = 500, 50
        halign = center
        valign = center
        text =  {user}
        font_family = JetBrainsMono Nerd Font
        font_size = 15
        font_color = rgba(255, 255, 255, 0.4)
        shadow_passes = 0
    }

    label {
        position = 20, 20
        size = 200, 50
        halign = left
        valign = top
        text = cmd[update:2000, wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%.0f%%", $2*100}']
        font_family = JetBrainsMono Nerd Font
        font_size = 15
        font_color = rgba(249, 226, 175, 1.0)
        shadow_passes = 0
    }

    label {
        position = 20, 20
        size = 200, 50
        halign = right
        valign = top
        text = cmd[update:5000, nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null | grep -v loopback | head -1 | cut -d: -f1 | xargs -I{} echo " {}" || echo " Bağlı Değil"]
        font_family = JetBrainsMono Nerd Font
        font_size = 15
        font_color = rgba(148, 226, 213, 1.0)
        shadow_passes = 0
    }

    button {
        position = -20, -20
        size = 50, 50
        halign = right
        valign = bottom
        font_family = JetBrainsMono Nerd Font
        font_size = 20
        text = ⏻
        on_click = wlogout
        font_color = rgba(243, 139, 168, 1.0)
        rounding = 10
        outline_thickness = 2
        outer_color = rgba(243, 139, 168, 0.3)
    }

    button {
        position = -80, -20
        size = 50, 50
        halign = right
        valign = bottom
        font_family = JetBrainsMono Nerd Font
        font_size = 20
        text = 💤
        on_click = systemctl suspend
        font_color = rgba(255, 255, 255, 0.8)
        rounding = 10
        outline_thickness = 2
        outer_color = rgba(255, 255, 255, 0.2)
    }
  '';

  waybarStyle = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 12px;
      font-weight: 500;
      min-height: 0;
    }

    #waybar {
      background: #000000;
      color: #ffffff;
      border-bottom: 1px solid #222222;
    }

    tooltip {
      background: #0a0a0a;
      border: 1px solid #cba6f7;
      border-radius: 8px;
    }

    tooltip label {
      color: #ffffff;
      padding: 2px 6px;
      font-size: 11px;
    }

    #workspaces {
      background: #0a0a0a;
      border-radius: 10px;
      margin: 4px 6px;
      padding: 0 4px;
    }

    #workspaces button {
      color: #888888;
      background: transparent;
      border: none;
      border-radius: 8px;
      padding: 4px 10px;
      margin: 3px 2px;
      font-weight: 600;
    }

    #workspaces button.active {
      color: #000000;
      background: #cba6f7;
    }

    #workspaces button:hover {
      color: #ffffff;
      background: #222222;
    }

    #window {
      color: #aaaaaa;
      padding: 4px 12px;
      font-style: italic;
      font-size: 11px;
    }

    #clock {
      font-size: 13px;
      font-weight: 600;
      color: #ffffff;
      background: #0a0a0a;
      padding: 4px 14px;
      border-radius: 10px;
      margin: 4px;
    }

    #cpu,
    #memory,
    #temperature,
    #pulseaudio,
    #network,
    #gamemode,
    #battery,
    #tray,
    #custom-temperature {
      padding: 4px 10px;
      margin: 4px 3px;
      border-radius: 10px;
      background: #0a0a0a;
    }

    #cpu.warning { color: #f9e2af; }
    #cpu.critical { color: #f38ba8; }
    #memory.warning { color: #f9e2af; }
    #memory.critical { color: #f38ba8; }

    #mpris {
      background: #111111;
      color: #cba6f7;
      border-radius: 10px;
      padding: 4px 10px;
      margin: 4px 3px;
    }

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
      color: #f38ba8;
      font-size: 15px;
      font-weight: bold;
      padding: 4px 12px;
      margin: 4px;
      background: #0a0a0a;
      border-radius: 10px;
    }

    #custom-power:hover {
      background: #222222;
    }
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
      persistent-workspaces = {
        "1" = []; "2" = []; "3" = [];
      };
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
      format = " {usage}%";
      format-alt = "⚡ {usage}%";
      tooltip = true;
      tooltip-format = "CPU kullanımı: {usage}%\nFrequency: {frequency} GHz";
      on-click = "kitty -e btop";
      states = {
        warning = 70;
        critical = 90;
      };
    };

    memory = {
      interval = 10;
      format = " {}%";
      format-alt = "🧠 {used:0.1f}G / {total:0.1f}G";
      tooltip = true;
      tooltip-format = "Kullanılan: {used:0.1f} GiB\nToplam: {total:0.1f} GiB\nBoş: {avail:0.1f} GiB";
      on-click = "kitty -e btop";
      states = {
        warning = 70;
        critical = 90;
      };
    };

    "custom/temperature" = {
      exec = "/home/localhost/.local/bin/waybar-temperature.sh";
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

    tray = {
      icon-size = 16;
      spacing = 8;
      show-passive-icons = true;
    };

    mpris = {
      player = ["spotify" "spotifyd" "com.spotify.Client" "firefox" "chromium" "brave-browser"];
      format = "{player_icon} {artist} - {title}";
      format-paused = "⏸ {artist} - {title}";
      format-stopped = "";
      player-icons = {
        default = "🎵"; spotify = ""; firefox = "🦊"; chromium = "";
      };
      status-icons = {
        paused = "⏸"; playing = "▶"; stopped = "■";
      };
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

  # ========== TÜM DOTFİLE'LAR NİX İLE YÖNETİLİYOR ==========

  xdg.configFile = {
    "hypr/hyprland.conf".text = hyprlandConf;
    "hypr/hyprlock.conf".text = hyprlockConf;
    "waybar/style.css".text = waybarStyle;
    "waybar/config.json".text = waybarConfig;
  };

  # Waybar sıcaklık betiği
  home.file.".local/bin/waybar-temperature.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # AMD GPU sıcaklığı veya CPU fallback
      temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      if [ -n "$temp" ]; then
        temp=$((temp / 1000))
        echo "{\"text\": \"🌡️ $temp°C\", \"class\": \"normal\"}"
      else
        echo "{\"text\": \"🌡️ N/A\", \"class\": \"error\"}"
      fi
    '';
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
        nrs = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
        nup = "nix flake update";
        nclean = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
        ntest = "sudo nixos-rebuild dry-activate --flake /etc/nixos#nixos";
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
        user.name = "Umpug";
        user.email = "141457520+kUmutUK@users.noreply.github.com";
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

  # Hypridle servisi
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        lock_cmd = "pidof hyprlock || hyprlock";
        ignore_dbus_inhibit = false;
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 600;
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          timeout = 900;
          on-timeout = "pidof hyprlock || hyprlock; systemctl suspend";
        }
      ];
    };
  };

  # mpvpaper servisi – canlı video duvar kağıdı (çalışan sürüm)
  systemd.user.services.mpvpaper = {
    Unit = {
      Description = "mpvpaper live wallpaper service (looped)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=/run/current-system/sw/bin";
      ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper -p --mpv-options \"loop=inf\" DP-3 /home/localhost/wallpaper/mylivewallpapers-com-Ryou-Yamada-Bocchi-the-Rock-4K.mp4";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.packages = with pkgs; [
    fd ripgrep jq wget curl file tree
    playerctl pamixer hyprpicker wev
    nano
  ];
}

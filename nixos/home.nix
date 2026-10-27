{
  config,
  pkgs,
  lib,
  ...
}:

let
  gitName = "changeme";
  gitEmail = "you@example.com";
  monitorOutput = "";
  # Hyprland 0.55+ uses Lua configuration. The monitor output is set by the installer;
  # an empty value remains a catch-all for manual setups.
  hyprlandMonitorMode = "preferred";
  wallpaperVideo = "${config.home.homeDirectory}/Downloads/arthur-leywin-the-beginning-after-the-end.3840x2160.mp4";

  # Reuse Bibata's designed plus cursor as the default pointer while preserving
  # its hand, text, resize, busy, and other context-specific cursors.
  plusCursorTheme = pkgs.runCommand "plus-cursor-theme" { } ''
        src="${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Ice"
        theme="$out/share/icons/Plus-Cursor"
        mkdir -p "$theme/cursors"
        test -f "$src/cursors/plus"

        for cursor in "$src"/cursors/*; do
          ln -s "$cursor" "$theme/cursors/$(basename "$cursor")"
        done

        # These aliases are the usual default arrow names used by XCursor clients.
        for alias in left_ptr default arrow top_left_arrow; do
          ln -sfn "$src/cursors/plus" "$theme/cursors/$alias"
        done

        cat > "$theme/index.theme" <<'EOF'
    [Icon Theme]
    Name=Plus-Cursor
    Comment=Plus-shaped default pointer based on Bibata-Modern-Ice
    Inherits=Bibata-Modern-Ice
    EOF
  '';

  pywal16Fixed = pkgs.pywal16.overridePythonAttrs (_: {
    __structuredAttrs = true;

    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.imagemagick ])
    ];
  });

  # Quote every argument passed to systemd `ExecStart` using systemd's escaping rules.
  # JSON quoting preserves spaces/special characters and escapes `%` and `$` to prevent
  # specifier and environment-variable expansion.
  escapeSystemdExecArg = arg: lib.replaceStrings [ "%" "$" ] [ "%%" "$$" ] (builtins.toJSON arg);

  # Keep command strings in Nix and serialize them as Lua string literals with toJSON;
  # this avoids hand-written Lua/shell quoting bugs during the hyprlang -> Lua migration.
  hyprlockCommand = "${pkgs.hyprlock}/bin/hyprlock";
  hyprpickerCommand = "${pkgs.hyprpicker}/bin/hyprpicker -a && notify-send 'Color' \"$(wl-paste)\" -t 2000";
  pcmanfmDesktopCommand = "${pkgs.pcmanfm}/bin/pcmanfm --desktop";
  hyprpolkitagentCommand = "${pkgs.hyprpolkitagent}/bin/hyprpolkitagent";
  clipboardTranslateCommand = "sh -c 'T=$(grim -g \"$(slurp)\" - | tesseract - stdout -l eng 2>/dev/null | trans -b :tr); [ -n \"$T\" ] && notify-send -t 10000 \"Translation\" \"$T\"'";
  screenshotCommand = "grim -g \"$(slurp)\" - | wl-copy";
  sattyScreenshotCommand = "grim -g \"$(slurp)\" - | satty -f - | wl-copy";
  systemdEnvironmentCommand = "${pkgs.bash}/bin/bash -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE HYPRLAND_DISPLAY; dbus-update-activation-environment --systemd --all; systemctl --user start gamemode-notify; if [ -n \"$1\" ]; then systemctl --user start mpvpaper-watchdog; fi' sh ${lib.escapeShellArg monitorOutput}";
  wallpaperMissingCommand = "${pkgs.bash}/bin/bash -c 'if [ -n \"$2\" ] && [ ! -e \"$1\" ]; then notify-send -t 15000 -u critical \"mpvpaper\" \"Live wallpaper file not found: $1. Change wallpaperVideo in home.nix, then restart mpvpaper-watchdog.\"; fi' sh ${lib.escapeShellArg wallpaperVideo} ${lib.escapeShellArg monitorOutput}";
  monitorValidationCommand = "${pkgs.bash}/bin/bash -c 'if [ -n \"$1\" ] && ! hyprctl monitors 2>/dev/null | grep -Fq -- \"Monitor $1 (\"; then notify-send -t 15000 -u critical \"mpvpaper\" \"Monitor output not found: $1. Set monitorOutput in home.nix to the exact hyprctl monitors name.\"; fi' sh ${lib.escapeShellArg monitorOutput}";

  gamemodeNotifyScript = pkgs.writeShellScriptBin "gamemode-notify" ''
    NOTIFY_SEND="${pkgs.libnotify}/bin/notify-send"
    ${pkgs.dbus}/bin/dbus-monitor --session \
      "type='signal',interface='com.feralinteractive.GameMode'" |
    while read -r line; do
      if echo "$line" | grep -q 'GameRegistered'; then
        $NOTIFY_SEND -i games "🎮 GameMode" "Active — high performance" -t 3000
      elif echo "$line" | grep -q 'GameUnregistered'; then
        count=$(${pkgs.systemd}/bin/busctl --user get-property com.feralinteractive.GameMode \
                  /com/feralinteractive/GameMode com.feralinteractive.GameMode ClientCount \
                  2>/dev/null | cut -d' ' -f2)
        if [ "$count" = "0" ]; then
          $NOTIFY_SEND -i games "🎮 GameMode" "Disabled — normal mode" -t 3000
        fi
      fi
    done
  '';

  gtkCss = ''
    @define-color accent_color              #EAB2C2;
    @define-color accent_fg_color           #1B1E25;
    @define-color accent_bg_color           #EAB2C2;
    @define-color window_bg_color           #1B1E25;
    @define-color window_fg_color           #CCD9FF;
    @define-color view_bg_color             #1B1E25;
    @define-color view_fg_color             #CCD9FF;
    @define-color headerbar_bg_color        #1B1E25;
    @define-color headerbar_fg_color        #CCD9FF;
    @define-color headerbar_border_color    #2F364A;
    @define-color headerbar_backdrop_color  #1B1E25;
    @define-color headerbar_shade_color     #1B1E25;
    @define-color card_bg_color             #232936;
    @define-color card_fg_color             #CCD9FF;
    @define-color card_shade_color          #1B1E25;
    @define-color popover_bg_color          #232936;
    @define-color popover_fg_color          #CCD9FF;
    @define-color dialog_bg_color           #1B1E25;
    @define-color dialog_fg_color           #CCD9FF;
    @define-color sidebar_bg_color          #1B1E25;
    @define-color sidebar_fg_color          #CCD9FF;
    @define-color sidebar_border_color      #2F364A;
    @define-color warning_color             #D9C95E;
    @define-color error_color               #EAB2C2;
    @define-color success_color             #76C4D7;
    @define-color destructive_color         #EAB2C2;
    @define-color destructive_bg_color      #EAB2C2;
    @define-color destructive_fg_color      #1B1E25;

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

  hyprlandLua = ''
    -- Declarative Hyprland Lua configuration, kept in nixos/home.nix.
    -- Inspired by the Steins-Rice palette/rounded look; core desktop services and
    -- established shortcuts from this configuration are retained.

    local mainMod = "SUPER"
    local monitorOutput = ${builtins.toJSON monitorOutput}
    local monitorMode = ${builtins.toJSON hyprlandMonitorMode}

    hl.monitor({
        output = monitorOutput,
        mode = monitorMode,
        position = "auto",
        scale = "1",
    })

    -- Rose / teal / gold accent palette used by the Rofi, Kitty, and GTK themes.
    local accent = "rgba(eab2c2ff)"
    local accentAlt = "rgba(76c4d7ff)"
    local background = "rgba(1b1e25ff)"

    hl.config({
        general = {
            gaps_in = 4,
            gaps_out = 8,
            border_size = 2,
            col = {
                active_border = { colors = { accent, accentAlt }, angle = 45 },
                inactive_border = background,
            },
            layout = "dwindle",
            allow_tearing = true,
            resize_on_border = true,
            no_focus_fallback = false,
        },
        input = {
            kb_layout = "tr",
            follow_mouse = 1,
            sensitivity = 0,
            accel_profile = "flat",
        },
        dwindle = {
            smart_resizing = true,
        },
        decoration = {
            rounding = 12,
            rounding_power = 2,
            dim_inactive = false,
            shadow = {
                enabled = true,
                range = 20,
                render_power = 3,
                offset = { 0, 5 },
                color = background,
            },
            blur = {
                enabled = true,
                size = 5,
                passes = 3,
                noise = 0.05,
                vibrancy = 0.25,
            },
        },
        misc = {
            vrr = 2,
            mouse_move_enables_dpms = true,
            key_press_enables_dpms = true,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            force_default_wallpaper = 0,
            animate_manual_resizes = false,
            animate_mouse_windowdragging = false,
            allow_session_lock_restore = true,
            session_lock_xray = true,
            enable_swallow = true,
            swallow_regex = "(kitty.*)",
        },
        cursor = {
            no_hardware_cursors = false,
            inactive_timeout = 3,
        },
        animations = {
            enabled = true,
        },
    })

    -- Current Lua API equivalent of the old bezier and animation declarations.
    hl.curve("smoothOut", { type = "bezier", points = { { 0.25, 0.05 }, { 0.1, 1.0 } } })
    hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
    hl.curve("bounce", { type = "bezier", points = { { 0.3, 1.6 }, { 0.6, 1.0 } } })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 7, bezier = "smoothOut", style = "slide" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "smoothOut", style = "slide" })
    hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "smoothOut" })
    hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slide" })
    hl.animation({ leaf = "layers", enabled = true, speed = 6, bezier = "overshot", style = "fade" })
    hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "smoothOut" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "overshot", style = "slidevert" })

    -- Applications and utility bindings.
    hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("rofi -show drun"))
    hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
    hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(${builtins.toJSON screenshotCommand}))
    hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(${builtins.toJSON sattyScreenshotCommand}))
    hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(${builtins.toJSON hyprlockCommand}))
    hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("pypr toggle term"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("pypr toggle music"))
    hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("pypr toggle filemanager"))

    -- Mouse wheel cycles through existing workspaces (not windows).
    hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

    -- Move, focus, and resize windows.
    for _, direction in ipairs({ "left", "right", "up", "down" }) do
        local shortDirection = ({ left = "l", right = "r", up = "u", down = "d" })[direction]
        hl.bind(mainMod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = shortDirection }))
        hl.bind(mainMod .. " + " .. direction, hl.dsp.focus({ direction = shortDirection }))
    end
    hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }))
    hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }))
    hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
    hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))
    hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
    hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
    hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
    hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
    hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
    hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }))
    hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }))
    hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
    hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))

    -- Workspaces 1-10 (Super+0 is workspace 10).
    for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
    end
    hl.bind(mainMod .. " + G", hl.dsp.group.toggle({}))
    hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

    -- Multimedia keys; repeating volume binds retain the old binde behavior.
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
    hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd(${builtins.toJSON hyprpickerCommand}))
    hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
    hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(${builtins.toJSON "${config.home.homeDirectory}/.config/hypr/scripts/toggle-wuwa.sh"}))
    hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(${builtins.toJSON clipboardTranslateCommand}))
    hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(${builtins.toJSON "${config.home.homeDirectory}/.config/hypr/scripts/toggle-auto-translate.sh"}))
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- Keep gaming windows direct/fullscreen and free from blur/shadow/animation.
    hl.window_rule({
        name = "cs2-gaming",
        match = { class = "^(cs2)$" },
        immediate = true,
        fullscreen = true,
        no_blur = true,
        no_shadow = true,
        no_anim = true,
        rounding = 0,
    })
    hl.window_rule({
        name = "gamescope-gaming",
        match = { class = "^(gamescope|Gamescope)$" },
        immediate = true,
        fullscreen = true,
        no_blur = true,
        no_shadow = true,
        no_anim = true,
        rounding = 0,
    })
    hl.window_rule({ name = "pavucontrol-float", match = { class = "^(pavucontrol)$" }, float = true, size = { 500, 600 } })
    hl.window_rule({ name = "nm-connection-editor-float", match = { class = "^(nm-connection-editor)$" }, float = true })
    hl.window_rule({
        name = "scratchterm-float",
        match = { title = "^(scratchterm)$" },
        float = true,
        size = { "monitor_w * 0.6", "monitor_h * 0.6" },
    })

    -- Start the existing desktop tools once, after Hyprland has initialized.
    -- Environment import precedes the optional mpvpaper watchdog start.
    hl.on("hyprland.start", function()
        hl.exec_cmd(${builtins.toJSON pcmanfmDesktopCommand})
        hl.exec_cmd("hyprctl setcursor Plus-Cursor 20")
        hl.exec_cmd("waybar")
        hl.exec_cmd("dunst")
        hl.exec_cmd("wl-paste --watch cliphist store")
        hl.exec_cmd("nm-applet --indicator")
        hl.exec_cmd(${builtins.toJSON hyprpolkitagentCommand})
        hl.exec_cmd("pypr")
        hl.exec_cmd(${builtins.toJSON systemdEnvironmentCommand})
        hl.exec_cmd(${builtins.toJSON wallpaperMissingCommand})
        hl.exec_cmd(${builtins.toJSON monitorValidationCommand})
    end)
  '';
  hyprlockConf = ''
    # Hyprlock 0.9.6 no longer accepts the old `grace` and `disable_loading_bar` options.
    # They were ignored with a warning. Grace is a CLI option and the loading bar was
    # removed; the previous zero grace value did not change the effective behavior.
    general {
        hide_cursor = 0
    }
    background { color = rgba(27, 30, 37, 1.0) }
    label {
        position = 0, -65; halign = center; valign = center;
        text = ; font_family = JetBrainsMono Nerd Font; font_size = 15;
        color = rgba(234, 178, 194, 1.0); shadow_passes = 0;
    }
    input-field {
        position = 0, -120; size = 300, 50; halign = center; valign = center;
        # Hyprlock 0.9.6 no longer registers `font_size`, `check_symbol`, `placeholder_color`,
        # or `fail_transition`; these keys were silently ignored. `check_symbol` maps to
        # `check_text`; font sizing and placeholder color are derived automatically, and the
        # supported fade options replace the removed transition option.
        placeholder_text = Password...; font_family = JetBrainsMono Nerd Font;
        dots_size = 0.55; dots_spacing = 0.15; check_text = ✓;
        font_color = rgba(204, 217, 255, 1.0);
        check_color = rgba(118, 196, 215, 1.0); fail_color = rgba(234, 178, 194, 1.0);
        hide_input = false; rounding = 10;
        outline_thickness = 2; outer_color = rgba(217, 201, 94, 0.85);
        inner_color = rgba(27, 30, 37, 0.95); shadow_passes = 0;
    }
    label {
        position = 0, 150; halign = center; valign = center;
        text =  $TIME; font_family = JetBrainsMono Nerd Font; font_size = 80;
        color = rgba(204, 217, 255, 1.0); shadow_passes = 0;
    }
    label {
        position = 0, 60; halign = center; valign = center;
        text = cmd[update:60000, LC_TIME=en_US.UTF-8 ${pkgs.coreutils}/bin/date +"%d %B %Y"];
        font_family = JetBrainsMono Nerd Font; font_size = 20;
        color = rgba(204, 217, 255, 0.75); shadow_passes = 0;
    }
    label {
        position = 0, 10; halign = center; valign = center;
        text =  $USER; font_family = JetBrainsMono Nerd Font; font_size = 15;
        color = rgba(204, 217, 255, 0.65); shadow_passes = 0;
    }
    label {
        position = 20, 20; halign = left; valign = top;
        text = cmd[update:2000, ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@ | ${pkgs.gawk}/bin/awk '{printf "%.0f%%", $2*100}'];
        font_family = JetBrainsMono Nerd Font; font_size = 15;
        color = rgba(217, 201, 94, 1.0); shadow_passes = 0;
    }
    label {
        position = 20, 20; halign = right; valign = top;
        text = cmd[update:5000, ${pkgs.networkmanager}/bin/nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v loopback | ${pkgs.coreutils}/bin/head -1 | ${pkgs.coreutils}/bin/cut -d: -f1 | ${pkgs.gawk}/bin/awk 'NF { print " " $0; found=1 } END { if (!found) print " Disconnected" }'];
        font_family = JetBrainsMono Nerd Font; font_size = 15;
        color = rgba(118, 196, 215, 1.0); shadow_passes = 0;
    }
    label {
        position = 0, -260; halign = center; valign = center;
        text = Unlock the screen to access session shortcuts
        font_family = JetBrainsMono Nerd Font; font_size = 14;
        color = rgba(204, 217, 255, 0.45); shadow_passes = 0;
    }
    # Hyprlock 0.9.6 removed the `button` widget, so the old wlogout/suspend buttons
    # were never rendered. The configured `SUPER+SHIFT+E` shortcut still exits Hyprland.
    # Use an older hyprlock release if clickable widgets are required.
  '';

  waybarStyle = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px; font-weight: 600; min-height: 0;
    }
    window#waybar {
      background: rgba(27, 30, 37, 0.96); color: #CCD9FF;
      border: 1px solid #2F364A; border-radius: 7px;
    }
    tooltip {
      background: #1B1E25; color: #CCD9FF; border: 1px solid #D9C95E;
      border-radius: 8px;
    }
    tooltip label { color: #CCD9FF; padding: 2px 6px; font-size: 11px; }
    #workspaces { background: #1B1E25; border-radius: 10px; margin: 4px 6px; padding: 0 4px; }
    #workspaces button {
      color: #EAB2C2; background: transparent; border: none;
      border-radius: 8px; padding: 4px 10px; margin: 3px 2px; font-weight: 600;
    }
    #workspaces button.active { color: #1B1E25; background: #EAB2C2; }
    #workspaces button:hover { color: #1B1E25; background: #76C4D7; }
    #window { color: #CCD9FF; padding: 4px 12px; font-style: italic; font-size: 11px; }
    #clock {
      font-size: 13px; font-weight: 700; color: #D9C95E;
      background: #1B1E25; padding: 4px 14px; border-radius: 10px; margin: 4px;
    }
    #cpu, #memory, #temperature, #pulseaudio, #network, #gamemode, #tray, #custom-temperature {
      padding: 4px 10px; margin: 4px 3px; border-radius: 10px;
      background: #1B1E25; border: 1px solid #2F364A;
    }
    #cpu.warning, #memory.warning { color: #D9C95E; }
    #cpu.critical, #memory.critical { color: #EAB2C2; }
    #mpris { background: #232936; color: #EAB2C2; border-radius: 10px; padding: 4px 10px; margin: 4px 3px; }
    #mpris.playing { color: #76C4D7; }
    #mpris.paused { color: #D9C95E; }
    #mpris.stopped { color: #8290A8; }
    #cpu { color: #76C4D7; }
    #memory { color: #EAB2C2; }
    #custom-temperature { color: #D9C95E; }
    #pulseaudio { color: #D9C95E; }
    #network { color: #76C4D7; }
    #gamemode { color: #EAB2C2; font-weight: bold; }
    #custom-power {
      color: #EAB2C2; font-size: 15px; font-weight: bold;
      padding: 4px 12px; margin: 4px; background: #1B1E25; border-radius: 10px;
    }
    #custom-power:hover { background: #2F364A; }
  '';

  waybarConfig = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 32;
    spacing = 4;
    margin-top = 6;
    margin-bottom = 0;
    margin-left = 8;
    margin-right = 8;
    modules-left = [
      "hyprland/workspaces"
      "hyprland/window"
    ];
    modules-center = [ "clock" ];
    modules-right = [
      "mpris"
      "gamemode"
      "cpu"
      "memory"
      "custom/temperature"
      "pulseaudio"
      "network"
      "tray"
      "custom/power"
    ];

    "hyprland/workspaces" = {
      format = "{name}";
      format-icons = {
        "1" = "一";
        "2" = "二";
        "3" = "三";
        "4" = "四";
        "5" = "五";
        "6" = "六";
        "7" = "七";
        "8" = "八";
        urgent = "！";
        active = "●";
        default = "○";
      };
      on-click = "activate";
      all-outputs = false;
      show-special = false;
      persistent-workspaces = {
        "1" = [ ];
        "2" = [ ];
        "3" = [ ];
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
      tooltip-format = "GameMode active: {count} games";
    };

    cpu = {
      interval = 5;
      format = " {usage}% {icon}";
      format-icons = [
        "▁"
        "▂"
        "▃"
        "▄"
        "▅"
        "▆"
        "▇"
        "█"
      ];
      format-alt = "⚡ {usage}%";
      tooltip = true;
      tooltip-format = "CPU usage: {usage}%\nFrequency: {frequency} GHz";
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
      tooltip-format = "Used: {used:0.1f} GiB\nTotal: {total:0.1f} GiB\nAvailable: {avail:0.1f} GiB";
      on-click = "kitty -e btop";
      states = {
        warning = 70;
        critical = 90;
      };
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
        headphone = "󰊋";
        hands-free = "󰂰";
        headset = "󰂰";
        phone = "󰉠";
        portable = "󰉠";
        car = "󰉠";
        default = [
          "🔈"
          "🔉"
          "🔊"
        ];
      };
      on-click = "pavucontrol";
      on-click-right = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
      on-scroll-up = "pactl set-sink-volume @DEFAULT_SINK@ +5%";
      on-scroll-down = "pactl set-sink-volume @DEFAULT_SINK@ -5%";
      tooltip = true;
      tooltip-format = "Volume: {volume}%\nOutput: {desc}";
      states = {
        muted = 0;
      };
    };

    network = {
      interval = 10;
      format-wifi = "📶 {signalStrength}%";
      format-ethernet = "🌐 {ipaddr}";
      format-disconnected = "⚠️ Disconnected";
      format-linked = "🌐 (No IP)";
      tooltip-format-wifi = "{essid} ({signalStrength}%)\nIP: {ipaddr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
      tooltip-format-ethernet = "Ethernet\nIP: {ipaddr}\n↑ {bandwidthUpBytes} ↓ {bandwidthDownBytes}";
      tooltip-format-disconnected = "Disconnected";
      on-click = "nm-connection-editor";
    };

    clock = {
      interval = 60;
      format = " {:%H:%M}";
      format-alt = "📅 {:%m/%d/%Y %H:%M}";
      tooltip-format = "<big>{:%Y %B}</big>\n{calendar}";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        weeks-pos = "right";
        on-scroll = 1;
        on-click-right = "mode";
        format = {
          months = "<span color='#CCD9FF'><b>{}</b></span>";
          days = "<span color='#CCD9FF'>{}</span>";
          weeks = "<span color='#76C4D7'><b>H{}</b></span>";
          weekdays = "<span color='#D9C95E'><b>{}</b></span>";
          today = "<span color='#EAB2C2'><b><u>{}</u></b></span>";
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
      player = [
        "spotify"
        "com.spotify.Client"
        "firefox"
        "chromium"
        "brave-browser"
      ];
      format = "{player_icon} {artist} - {title}";
      format-paused = "⏸ {artist} - {title}";
      format-stopped = "";
      player-icons = {
        default = "🎵";
        spotify = "󰀒";
        firefox = "🦊";
        chromium = "🌐";
      };
      status-icons = {
        paused = "⏸";
        playing = "▶";
        stopped = "■";
      };
      max-length = 40;
      on-click = "playerctl play-pause";
      on-click-right = "playerctl stop";
      tooltip-format = "{player}\n{status}\n{artist} — {album}\n{title}";
    };

    "custom/power" = {
      format = "⏻";
      tooltip = true;
      tooltip-format = "Power menu (wlogout)";
      on-click = "wlogout";
      on-click-right = "wlogout";
    };
  };
in
{
  home.username = "localhost";
  home.homeDirectory = "/home/localhost";
  home.stateVersion = "26.05";

  # Pin the native Lua configuration explicitly, including when greetd starts Hyprland
  # before another desktop-session environment has been imported.
  home.sessionVariables = {
    HYPRLAND_CONFIG = "${config.home.homeDirectory}/.config/hypr/hyprland.lua";
    XCURSOR_THEME = "Plus-Cursor";
    XCURSOR_SIZE = "20";
  };

  # Verify the active config with `hyprctl configversion` and inspect the log if Lua
  # reports a syntax/API error during startup.

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
      name = "Tela-circle-dracula";
      package = pkgs.tela-circle-icon-theme.override {
        colorVariants = [ "dracula" ];
      };
    };
    gtk3.extraCss = gtkCss;
    gtk4.extraCss = gtkCss;
  };

  home.pointerCursor = {
    enable = true;
    name = "Plus-Cursor";
    package = plusCursorTheme;
    size = 20;
    gtk.enable = true;
    x11.enable = true;
  };

  xdg.configFile = {
    # A compact Rofi theme inspired by the public dotfiles. The Super+A binding
    # uses this managed theme rather than forcibly selecting Rofi's stock `arthur`.
    "rofi/config.rasi".text = ''
      configuration {
        modi: "drun,run,window";
        show-icons: true;
        terminal: "kitty";
        drun-display-format: "{name}";
        matching: "fuzzy";
        sort: true;
        case-sensitive: false;
      }
      @theme "~/.config/rofi/themes/theme.rasi"
    '';
    "rofi/themes/theme.rasi".text = ''
      * {
        main-bg: #1B1E25;
        main-fg: #CCD9FF;
        main-br: #D9C95E;
        main-ex: #76C4D7;
        select-bg: #EAB2C2;
        select-fg: #1B1E25;
        urgent: #EAB2C2;
        background-color: @main-bg;
        text-color: @main-fg;
      }
      window {
        width: 42%;
        border: 2px;
        border-color: @main-br;
        border-radius: 12px;
        background-color: @main-bg;
      }
      mainbox { padding: 12px; background-color: @main-bg; }
      inputbar {
        padding: 8px 10px;
        border: 1px;
        border-color: @main-ex;
        border-radius: 8px;
        background-color: #232936;
        children: [ prompt, entry ];
        spacing: 8px;
      }
      prompt { text-color: @main-ex; }
      entry { text-color: @main-fg; placeholder: "Search…"; }
      listview { lines: 8; columns: 1; fixed-height: false; padding: 8px 0 0; spacing: 3px; }
      element {
        padding: 7px 10px;
        border-radius: 7px;
        background-color: transparent;
        text-color: @main-fg;
      }
      element normal.normal { background-color: transparent; text-color: @main-fg; }
      element selected.normal { background-color: @select-bg; text-color: @select-fg; }
      element alternate.normal { background-color: #232936; }
      element selected.active { background-color: @main-ex; text-color: @main-bg; }
      element-text { background-color: inherit; text-color: inherit; }
      element-icon { size: 1.2em; background-color: inherit; }
      scrollbar { handle-width: 4px; border: 0; border-color: @main-bg; }
    '';
    "ranger/rc.conf".text = ''
      set preview_images true
      set preview_images_method kitty
      set show_hidden true
      set sort_directories_first true
      set confirm_on_delete multiple
      set draw_borders both
      set vcs_aware false
    '';
    # Keep Fish as the login shell; translate safe convenience aliases instead of
    # importing the upstream Zsh/Oh-My-Zsh setup or its Arch-only update command.
    "fish/conf.d/bocchi-theme.fish".text = ''
      if status is-interactive
          if type -q eza
              alias ls 'eza --icons --color=always --group-directories-first'
              alias ll 'eza -alF --icons --color=always --group-directories-first'
              alias la 'eza -a --icons --color=always --group-directories-first'
              alias l 'eza -F --icons --color=always --group-directories-first'
          end
          alias c clear
          if test -r "$HOME/.cache/wal/sequences"
              command cat "$HOME/.cache/wal/sequences"
          end
      end
    '';
    "hypr/hyprland.lua".text = hyprlandLua;
    "hypr/hyprlock.conf".text = hyprlockConf;
    "waybar/style.css".text = waybarStyle;
    "waybar/config.jsonc".text = waybarConfig;

    # Toggle scripts are used because an inline `pkill -f ... || ...` command matches and
    # kills its own `sh -c` wrapper. The separate `toggle-wuwa.sh` does not match the
    # `wuwa-auto[.]sh` pattern. Its start/stop behavior and the real `sh -c` call path were
    # checked in a sandbox.
    "hypr/scripts/toggle-wuwa.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        if pgrep -f "hypr/scripts/wuwa-auto[.]sh" >/dev/null 2>&1; then
          pkill -f "hypr/scripts/wuwa-auto[.]sh"
          notify-send "WuWa AI" "Stopped" -t 2000
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
          notify-send "Automatic Translation" "Stopped" -t 2000
        else
          exec "$HOME/.config/hypr/scripts/auto-translate.sh"
        fi
      '';
    };

    # These files had been stored in the repository but were never deployed. The
    # Home Manager definitions below now put MangoHud and lsfg-vk configuration in the
    # user's active configuration directory.
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

      # The frame-generation multiplier is selected per executable; the `exe` field must
      # match the actual process name (for example, `GenshinImpact`, not `Genshin`).
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

      # Common Proton/Wine process aliases. Confirm the actually matched name in
      # the LSFG-VK log on the target machine.
      [[game]]
      exe = "Client-Win64-Shipping.exe"
      multiplier = 2
      flow_scale = 0.9
      performance_mode = false
      hdr_mode = true
      experimental_present_mode = "fifo"

      [[game]]
      exe = "Client-Win64-Shipping"
      multiplier = 2
      flow_scale = 0.9
      performance_mode = false
      hdr_mode = true
      experimental_present_mode = "fifo"
    '';

    # Pyprland was installed but lacked a valid configuration for the scratchpad keybinds.
    # The canonical config path is `~/.config/pypr/config.toml`; the older
    # `~/.config/hypr/pyprland.toml` is still read but causes a migration warning. The
    # config uses `[pyprland]` plus `[scratchpads.<name>]`; the older `[[pypr.apps]]` layout
    # is not read by pyprland.
    "pypr/config.toml".text = ''
      [pyprland]
      plugins = [ "scratchpads" ]

      # Hyprland Lua binding: SUPER+S runs `pypr toggle term`.
      [scratchpads.term]
      animation = "fromTop"
      command = "kitty --class pypr-term"
      class = "pypr-term"
      size = "70% 60%"
      margin = 50

      # The music scratchpad launches `mpv`. `playerctl` has no window of its own because
      # it controls a media player. Change the command/class values if you prefer another player.
      [scratchpads.music]
      animation = "fromRight"
      command = "mpv --class pypr-music --no-config --idle"
      class = "pypr-music"
      size = "45% 70%"
      unfocus = "hide"
      lazy = true

      # Hyprland Lua binding: SUPER+CTRL+S runs `pypr toggle filemanager`.
      [scratchpads.filemanager]
      animation = "fromRight"
      command = "pcmanfm"
      class = "pcmanfm"
      size = "60% 70%"
      lazy = true
    '';

    # These scripts used repository-relative `../.config/hypr/scripts/*.sh` paths, but
    # `install.sh` copies Nix configuration and hooks, not the repository's `.config/`
    # directory. Such paths did not exist after installation. Embed scripts in this Nix
    # file so they are deployed regardless of where `home.nix` is copied.
    "hypr/scripts/wuwa-auto.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash
        # shellcheck disable=SC2155
        # SC2155 is intentional here: the four local assignments do not use their return
        # status, and the script does not enable `set -e`. Embedded-script scanning was added
        # to CI on 2026-10-05.

        # The custom Ollama alias `wuwa-gemma` is based on Aya Expanse 8B and requires a
        # first-run model download via `wuwa-gemma-init`. If it is missing, `/api/generate`
        # may return `null`; stop before entering the OCR loop instead of emitting invalid output.
        if ! curl -fsS --connect-timeout 2 --max-time 4 http://localhost:11434/api/tags \
            | jq -e '.models[]? | select(.name | startswith("wuwa-gemma"))' >/dev/null 2>&1; then
            notify-send -u critical "WuWa AI" \
                "The wuwa-gemma model is not ready. Start it first: sudo systemctl start wuwa-gemma-init" || true
            exit 1
        fi

        ## OCR region definitions
        # The former coordinates were hard-coded for 2560x1440 and could lie outside other
        # resolutions. `WUWA_GEOMETRY_MAIN` and `WUWA_GEOMETRY_CHOICE` can override them; the
        # script now warns and exits if a region does not fit the detected display.
        DEFAULT_GEOMETRY_MAIN="0,971 2560x438"
        DEFAULT_GEOMETRY_CHOICE="1561,513 916x585"

        GEOMETRY_MAIN="''${WUWA_GEOMETRY_MAIN:-$DEFAULT_GEOMETRY_MAIN}"
        GEOMETRY_CHOICE="''${WUWA_GEOMETRY_CHOICE:-$DEFAULT_GEOMETRY_CHOICE}"

        # Read the display size from `hyprctl`. If it is missing or unreadable, geometry
        # validation is skipped. `hyprctl monitors` includes a refresh rate such as
        # `2560x1440@170.00`; strip the `@...` suffix before parsing the height.
        MON_SIZE=$(hyprctl monitors 2>/dev/null | grep -oPm1 '[0-9]+x[0-9]+@[0-9.]+' | head -n1 | cut -d@ -f1)
        MON_W=$(echo "$MON_SIZE" | cut -dx -f1)
        MON_H=$(echo "$MON_SIZE" | cut -dx -f2)

        # Check whether an `X,Y WxH` rectangle fits within the display dimensions.
        geometry_fits() {
            [ -n "$MON_W" ] && [ -n "$MON_H" ] || return 0
            local pos size x y w h
            pos=$(echo "$1" | cut -d' ' -f1)
            size=$(echo "$1" | cut -d' ' -f2)
            x=$(echo "$pos" | cut -d, -f1)
            y=$(echo "$pos" | cut -d, -f2)
            w=$(echo "$size" | cut -dx -f1)
            h=$(echo "$size" | cut -dx -f2)
            # For non-numeric geometry (for example, a typo), preserve the earlier permissive
            # behavior and skip the fit check.
            case "$x$y$w$h" in *[!0-9]*) return 0 ;; esac
            [ $(( x + w )) -le "$MON_W" ] && [ $(( y + h )) -le "$MON_H" ]
        }

        # Hyprland reports monitor position as well as dimensions, but this check compares
        # only width/height. This is exact for a single monitor and may be conservative for
        # multi-monitor layouts.
        for _region in "captions|$GEOMETRY_MAIN" "choices|$GEOMETRY_CHOICE"; do
            _label=$(echo "$_region" | cut -d'|' -f1)
            _geom=$(echo "$_region" | cut -d'|' -f2)
            if ! geometry_fits "$_geom"; then
                notify-send -t 25000 -u critical "WuWa AI" \
                    "The $_label region ($_geom) does not fit on the screen ($MON_W x $MON_H). Translation cannot scan this region. Adjust the wuwa-auto.sh values in home.nix or the WUWA_GEOMETRY_MAIN / WUWA_GEOMETRY_CHOICE environment variable." || true
                exit 1
            fi
        done

        # Create screenshots in a unique per-run temporary directory with user-only permissions.
        umask 077
        TMPD=$(mktemp -d -t wuwa-XXXXXX) || exit 1
        trap 'rm -rf "$TMPD"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM
        IMAGE_MAIN="$TMPD/main.png"
        IMAGE_CHOICE="$TMPD/choice.png"

        LAST_MAIN=""
        LAST_CHOICE=""

        # ─── Preferred Tesseract model directory ───
        TESSDATA_DIR="$HOME/.local/share/tessdata"

        # If the local Tesseract data directory is absent, fall back to the system tessdata path.
        [ ! -d "$TESSDATA_DIR" ] && TESSDATA_DIR="/run/current-system/sw/share/tessdata"

        # Translation cache.
        CACHE_HOME="''${XDG_CACHE_HOME:-$HOME/.cache}"
        CACHE_FILE="$CACHE_HOME/wuwa_translate_cache"
        mkdir -p "$CACHE_HOME" || exit 1
        touch "$CACHE_FILE" && chmod 600 "$CACHE_FILE" || exit 1

        # Fast translation (Argos Translate).
        translate_fast() {
            # The `argos-translate` binary is not available in nixpkgs (only the Python
            # `argos-translate-files` package exists). Previously the failure was hidden and every
            # request fell through to Ollama. Check command availability and fall back explicitly.
            command -v argos-translate >/dev/null 2>&1 || return 1
            echo "$1" | argos-translate --from-lang en --to-lang tr 2>/dev/null
        }

        # Fallback translation via Ollama using a JSON request.
        translate_llm() {
            local text="$1"
            # `jq --arg` does not interpret C-style escapes; a literal `\n` was sent to the model.
            # The shell code is embedded in a Nix indented string, so use Bash ANSI-C quoting
            # (`$'\n'`) to guarantee a real line break in the prompt after Nix interpolation.
            local json_payload
            json_payload=$(jq -n --arg mod "wuwa-gemma" \
                                 --arg pr "EN: ''${text}"$'\n'"TR:" \
                                 '{model: $mod, prompt: $pr, stream: false, options: {temperature: 0.0, num_predict: 80}}')

            local response translated
            response="$(curl --fail --silent --show-error \
                --connect-timeout 2 --max-time 10 \
                -H 'Content-Type: application/json' \
                http://localhost:11434/api/generate -d "$json_payload")" || return 1

            translated="$(jq -er '.response | select(type == "string" and length > 0)' \
                <<< "$response")" || return 1
            # Trim surrounding whitespace without interpreting quotes or backslashes.
            translated="''${translated#"''${translated%%[![:space:]]*}"}"
            translated="''${translated%"''${translated##*[![:space:]]}"}"
            [ -n "$translated" ] || return 1
            printf '%s\n' "$translated"
        }

        # General translation flow: cache, then Argos, then Ollama.
        translate() {
            local raw="$1"
            local letter_count=$(echo "$raw" | tr -cd 'a-zA-Z' | wc -c)
            [ "$letter_count" -lt 5 ] && { echo ""; return; }

            # Match the cache key against the complete first TAB-delimited field, not a substring.
            local cached=$(awk -F '\t' -v k="$raw" '$1 == k { print $2; exit }' "$CACHE_FILE" 2>/dev/null)
            [ -n "$cached" ] && { echo "$cached"; return; }

            # Try the fast translation backend first.
            local fast=$(translate_fast "$raw")
            if [ -n "$fast" ] && [ "''${#fast}" -gt 2 ]; then
                printf '%s\t%s\n' "$raw" "$fast" >> "$CACHE_FILE"
                echo "$fast"
                return
            fi

            # Ask the Aya Expanse 8B-based `wuwa-gemma` fallback if the fast backend fails.
            local llm=$(translate_llm "$raw")
            if [ -n "$llm" ]; then
                printf '%s\t%s\n' "$raw" "$llm" >> "$CACHE_FILE"
                echo "$llm"
                return
            fi
        }

        # Main loop. The old fixed 3-second loop ran two `grim`, two `mogrify`, and two
        # Tesseract processes even when the screen did not change. Back off gradually from
        # 3 to 30 seconds when both regions remain unchanged, and return to 3 seconds on change.
        IDLE_TICKS=0
        MAX_IDLE_SLEEP=30

        while true; do
            CHANGED=0
            # 1. Main subtitle region.
            grim -g "$GEOMETRY_MAIN" "$IMAGE_MAIN" 2>/dev/null
            mogrify -resize 200% \
                    -modulate 100,0 \
                    -colorspace Gray \
                    -lat 20x20+5% \
                    -negate \
                    -sharpen 0x2 \
                    "$IMAGE_MAIN" 2>/dev/null

            RAW_MAIN=$(tesseract "$IMAGE_MAIN" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
            # Do not use `tr -d \f`: Nix unescaping turned it into `tr -d f`, removing every
            # letter `f` from OCR results; `\014` similarly became the characters `014`. The
            # following `sed` filter already removes form-feed characters, so `tr` is unnecessary.
            TEXT_MAIN=$(echo "$RAW_MAIN" | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

            if [ ''${#TEXT_MAIN} -gt 5 ]; then
                if [ "$TEXT_MAIN" != "$LAST_MAIN" ]; then
                    LAST_MAIN="$TEXT_MAIN"
                    CHANGED=1
                    TRANSLATION_MAIN=$(translate "$TEXT_MAIN")
                    [ -n "$TRANSLATION_MAIN" ] && notify-send -r 9999 "💬 Wuwa AI (Captions)" "$TRANSLATION_MAIN"
                fi
            else
                [ -n "$LAST_MAIN" ] && { LAST_MAIN=""; dunstctl close 9999 2>/dev/null || true; }
            fi
            rm -f "$IMAGE_MAIN" 2>/dev/null

            # 2. Choice/answer region.
            grim -g "$GEOMETRY_CHOICE" "$IMAGE_CHOICE" 2>/dev/null
            mogrify -resize 200% \
                    -modulate 100,0 \
                    -colorspace Gray \
                    -lat 20x20+5% \
                    -negate \
                    -sharpen 0x2 \
                    "$IMAGE_CHOICE" 2>/dev/null

            RAW_CHOICE=$(tesseract "$IMAGE_CHOICE" stdout -l eng --psm 6 --tessdata-dir "$TESSDATA_DIR" 2>/dev/null)
            # The `tr -d \f` filter was removed for the same Nix escaping reason; `sed` already
            # filters form-feed characters.
            TEXT_CHOICE=$(echo "$RAW_CHOICE" | sed 's/[^a-zA-Z0-9.,!? ]//g' | xargs)

            if [ ''${#TEXT_CHOICE} -gt 5 ]; then
                if [ "$TEXT_CHOICE" != "$LAST_CHOICE" ]; then
                    LAST_CHOICE="$TEXT_CHOICE"
                    CHANGED=1
                    TRANSLATION_CHOICE=$(translate "$TEXT_CHOICE")
                    [ -n "$TRANSLATION_CHOICE" ] && notify-send -r 9998 "💡 Wuwa AI (Choices)" "$TRANSLATION_CHOICE"
                fi
            else
                [ -n "$LAST_CHOICE" ] && { LAST_CHOICE=""; dunstctl close 9998 2>/dev/null || true; }
            fi
            rm -f "$IMAGE_CHOICE" 2>/dev/null

            # Increase the retry delay gradually (3, 6, 9 seconds, up to 30 seconds).
            if [ "$CHANGED" -eq 1 ]; then
                IDLE_TICKS=0
                sleep 3
            else
                IDLE_TICKS=$((IDLE_TICKS + 1))
                S=$((3 + IDLE_TICKS * 3))
                [ "$S" -gt "$MAX_IDLE_SLEEP" ] && S=$MAX_IDLE_SLEEP
                sleep "$S"
            fi
        done
      '';
    };
    "hypr/scripts/auto-translate.sh" = {
      executable = true;
      text = ''
        #!${pkgs.bash}/bin/bash

        # Remember the previous selection to avoid translating the same text repeatedly.
        LAST_SELECTION=""

        echo "Live translation mode is active. Selected text will be translated automatically."

        # Poll the primary selection (the text highlighted with the mouse) in a lightweight
        # loop instead of relying on `wl-paste --watch`.
        while true; do
            # Read the current mouse-selected text.
            CURRENT_SELECTION=$(wl-paste -p 2>/dev/null)

            # Proceed only when the selection is non-empty and differs from the previous value.
            if [ -n "$CURRENT_SELECTION" ] && [ "$CURRENT_SELECTION" != "$LAST_SELECTION" ]; then
                LAST_SELECTION="$CURRENT_SELECTION"

                # Use `translate-shell` to translate the selected text to Turkish (`:tr`); `-b` keeps
                # only the translated output.
                TRANSLATION=$(trans -b :tr "$CURRENT_SELECTION" 2>/dev/null)

                # Display successful translations using Dunst.
                if [ -n "$TRANSLATION" ]; then
                    # Reuse notification ID 9997 so the notification is updated instead of stacked.
                    notify-send -r 9997 "Translation:" "$TRANSLATION"
                fi
            fi
            # Poll every half second to keep CPU usage low.
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

  # mpvpaper watchdog unit; `BindsTo` was removed.
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
        echo "Hyprland socket not found." >&2
        exit 1
      fi
    '';
  };

  # Home Manager persistence is intentionally disabled because this configuration does
  # not use impermanence and no data is stored under `/nix/persist`. The former commented
  # `home.persistence` entry never ran, while the flake/module/tmpfiles configuration had
  # also been inactive. Do not persist the declarative `lsfg-vk/conf.toml`: doing so can
  # shadow future Nix-generated changes. To re-enable persistence, restore the input,
  # NixOS `environment.persistence`/tmpfiles rules, and this Home Manager block together.
  #home.persistence."/nix/persist/home" = {
  #  files = [ ".config/lsfg-vk/conf.toml" ];
  #};

  programs = {
    # `programs.home-manager.enable = true` applies to standalone Home Manager usage.
    # This configuration imports Home Manager as a NixOS module, where that option is
    # intentionally ineffective; keeping it here would be misleading. Restore it only if
    # Home Manager is run standalone rather than through NixOS.

    fish = {
      enable = true;
      shellAliases = {
        cat = "bat";
        nrs = "sudo nixos-rebuild switch --flake /etc/nixos/nixos#nixos";
        nup = "sudo nix flake update --flake /etc/nixos/nixos cachyos-kernel";
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
        # PAGER: use plain `less` for ordinary files.
        set -gx PAGER 'less -R'

          # MANPAGER: `bat` produced broken ANSI sequences with the NixOS man-db/groff setup.
          # Use `less -R`, which supports the ANSI colors generated by man-db.
        set -gx MANPAGER 'less -R'
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
          error_symbol = "[❯](bold red)";
        };
        directory = {
          style = "bold cyan";
          truncation_length = 3;
          truncate_to_repo = false;
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        git_status.style = "bold yellow";
        cmd_duration = {
          min_time = 2000;
          style = "bold yellow";
          format = "[$duration]($style) ";
        };
        time = {
          disabled = false;
          format = "[$time]($style) ";
          style = "bold dimmed white";
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

    # Keep Kitty settings in this Home Manager module only. The theme matches the
    # rose/teal/gold palette used by Hyprland and Rofi; don't declare kitty.conf again
    # through xdg.configFile, or the generated file has competing owners.
    kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };
      settings = {
        foreground = "#CCD9FF";
        background = "#1B1E25";
        selection_foreground = "#1B1E25";
        selection_background = "#EAB2C2";
        cursor = "#EAB2C2";
        cursor_text_color = "#1B1E25";
        url_color = "#76C4D7";
        color0 = "#1B1E25";
        color1 = "#EAB2C2";
        color2 = "#76C4D7";
        color3 = "#D9C95E";
        color4 = "#76C4D7";
        color5 = "#EAB2C2";
        color6 = "#76C4D7";
        color7 = "#CCD9FF";
        color8 = "#8290A8";
        color9 = "#F2C6D2";
        color10 = "#97D5E2";
        color11 = "#E8D982";
        color12 = "#91D2E0";
        color13 = "#F0C4D1";
        color14 = "#A6DFE9";
        color15 = "#FFFFFF";
        window_padding_width = 20;
        confirm_os_window_close = 0;
        cursor_shape = "beam";
        cursor_blink_interval = "0.5";
        scrollback_lines = 10000;
        repaint_delay = 10;
        input_delay = 3;
        background_opacity = "0.97";
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
          # Do not call hyprlock here: it blocks in the foreground until the password is entered,
          # so a following `systemctl suspend` would never execute. `general.before_sleep_cmd`
          # already locks the screen; this command should only suspend.
          timeout = 900;
          on-timeout = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
    };
  };

  systemd.user.services = {
    # An empty `monitorOutput` disables live wallpaper for a manual Home Manager setup.
    # The installer requires a real output name before continuing.
    mpvpaper = lib.mkIf (monitorOutput != "") {
      Unit = {
        Description = "mpvpaper live wallpaper service (looped)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionPathExists = "${wallpaperVideo}";
      };
      Service = {
        Type = "simple";
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.mpvpaper
            pkgs.mpv
          ]
        }";
        ExecStart = lib.concatStringsSep " " (
          map escapeSystemdExecArg [
            "${pkgs.mpvpaper}/bin/mpvpaper"
            "-p"
            "--mpv-options"
            "loop=inf"
            monitorOutput
            wallpaperVideo
          ]
        );
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    mpvpaper-watchdog = lib.mkIf (monitorOutput != "") {
      Unit = {
        Description = "Stop the live wallpaper when Brave starts.";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.hyprland
            pkgs.jq
            pkgs.socat
            pkgs.systemd
            pkgs.gawk
          ]
        }";
        ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/.local/bin/mpvpaper-watchdog";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    gamemode-notify = {
      Unit = {
        Description = "Notify about GameMode state changes through Dunst.";
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
        Environment = "PATH=${
          lib.makeBinPath [
            pkgs.libnotify
            pkgs.dbus
            pkgs.gnugrep
            pkgs.systemd
            pkgs.coreutils
          ]
        }";
      };
    };
  };

  home.packages = with pkgs; [
    # P1-2 history: the music scratchpad previously invoked `mpv`, but the package was not
    # installed in either package list; mpvpaper's private PATH did not make it available
    # to the scratchpad. `mpv` is now included in the Home Manager package list.
    mpv
    # Optional tools for the adapted dotfile theme; Pywal is user-invoked (wal -i).
    eza
    ranger
    pywal16Fixed
    fd
    ripgrep
    jq
    wget
    curl
    file
    tree
    # `playerctl`, `wev`, `libnotify`, and `hyprpicker` are installed system-wide
    # in `configuration.nix`; keep them out of this Home Manager list to avoid duplicates.
    # `mpv` remains here because the music scratchpad invokes it directly.
    pamixer
    nano
    satty
    socat
  ];
}

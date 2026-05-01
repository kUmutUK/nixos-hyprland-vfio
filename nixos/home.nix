# home.nix — 10/10 (GTK CSS gömüldü, saf siyah tema)

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
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 16;
    };
    gtk3.extraCss = gtkCss;
    gtk4.extraCss = gtkCss;
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

  services = {
    hypridle = {
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
  };

  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.waypaper-random = {
    Unit = {
      Description = "Random wallpaper changer";
      After = [ "graphical-session.target" "awww-daemon.service" ];
      Requires = [ "awww-daemon.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.waypaper}/bin/waypaper --random";
    };
  };

  systemd.user.timers.waypaper-random = {
    Unit.Description = "Random wallpaper changer timer";
    Timer = {
      OnActiveSec = "5min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  home.packages = with pkgs; [
    fd ripgrep jq wget curl file tree
    playerctl pamixer hyprpicker wev
    nano
  ];
}

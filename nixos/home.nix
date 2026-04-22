# =============================================================================
# home.nix - Home Manager Yapılandırması
# =============================================================================

{ config, pkgs, lib, ... }:

{
  home.username = "localhost";
  home.homeDirectory = "/home/localhost";
  # system.stateVersion ile eşleşmeli.
  home.stateVersion  = "26.05";

  # =========================================================================
  # PROGRAMLAR
  # =========================================================================

  programs = {

    home-manager.enable = true;

    # -----------------------------------------------------------------------
    # FISH KABUK
    # -----------------------------------------------------------------------
    fish = {
      enable = true;

      shellAliases = {
        ll       = "eza -la --icons";
        la       = "eza -a --icons";
        l        = "eza -lah --icons";
        cat      = "bat";
        nrs      = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
        nup      = "nix flake update";
        nclean   = "nix-collect-garbage -d && sudo nix-collect-garbage -d";
        ntest    = "sudo nixos-rebuild dry-activate --flake /etc/nixos#nixos";
        lock     = "hyprlock";
        suspend  = "systemctl suspend";
        reboot   = "systemctl reboot";
        shutdown = "systemctl poweroff";

        # Btrfs / Snapper
        snap-root = "sudo snapper -c root list";
        snap-home = "sudo snapper -c home list";
        snap-diff = "sudo snapper -c root diff";
        btrfs-df  = "sudo btrfs filesystem df /";
        btrfs-cmp = "sudo compsize -x /";

        # GameMode
        gm-status = "gamemoded -s";
      };

      interactiveShellInit = ''
        starship init fish | source
        zoxide init fish | source
        set -gx MANPAGER "sh -c 'col -bx | bat -l man -p --paging=always'"
      '';

      shellInit = ''
        set -gx fish_greeting ""
      '';
    };

    # -----------------------------------------------------------------------
    # STARSHIP PROMPT
    # -----------------------------------------------------------------------
    starship = {
      enable   = true;
      settings = {
        format = "$directory$git_branch$git_status$character";
        right_format = "$cmd_duration$time";
        add_newline  = false;
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol   = "[❯](bold red)";
        };
        directory = {
          style            = "bold cyan";
          truncation_length = 3;
          truncate_to_repo  = false;
        };
        git_branch = {
          symbol = " ";
          style  = "bold purple";
        };
        git_status = {
          style = "bold yellow";
        };
        cmd_duration = {
          min_time = 2000;
          style    = "bold yellow";
          format   = "[$duration]($style) ";
        };
        time = {
          disabled  = false;
          format    = "[$time]($style) ";
          style     = "bold dimmed white";
          time_format = "%H:%M";
        };
      };
    };

    # -----------------------------------------------------------------------
    # ZOXIDE
    # -----------------------------------------------------------------------
    zoxide = {
      enable                = true;
      enableFishIntegration = true;
    };

    # -----------------------------------------------------------------------
    # FZF
    # -----------------------------------------------------------------------
    fzf = {
      enable                = true;
      enableFishIntegration  = true;
      defaultOptions = [
        "--height 40%"
        "--border"
        "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
        "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
        "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
      ];
    };

    # -----------------------------------------------------------------------
    # EZA
    # -----------------------------------------------------------------------
    eza = {
      enable                = true;
      enableFishIntegration  = true;
      git                   = true;
      icons                 = true;
    };

    # -----------------------------------------------------------------------
    # BAT
    # -----------------------------------------------------------------------
    bat = {
      enable = true;
      config = {
        theme = "base16";
        style = "numbers,changes,header";
      };
    };

    # -----------------------------------------------------------------------
    # GIT
    # -----------------------------------------------------------------------
    git = {
      enable    = true;
      userName  = "Umpug";
      userEmail = "141457520+kUmutUK@users.noreply.github.com";
      extraConfig = {
        core.editor  = "nano";
        core.autocrlf = "input";
        pull.rebase  = false;
        push.default = "simple";
        init.defaultBranch = "main";
        diff.colorMoved = "default";
      };
    };

    # -----------------------------------------------------------------------
    # HTOP
    # -----------------------------------------------------------------------
    htop = {
      enable = true;
      settings = {
        color_scheme        = 0;
        show_cpu_frequency  = 1;
        show_program_path   = 0;
        highlight_base_name = 1;
        tree_view           = 1;
      };
    };

    # -----------------------------------------------------------------------
    # BTOP
    # -----------------------------------------------------------------------
    btop = {
      enable   = true;
      settings = {
        color_theme      = "catppuccin_mocha";
        theme_background = false;
        truecolor        = true;
        vim_keys         = true;
        update_ms        = 1000;
        proc_sorting     = "cpu lazy";
        proc_tree        = false;
        cpu_graph_upper  = "total";
        mem_graphs       = true;
        show_gpu_info    = "Auto";
      };
    };

    # -----------------------------------------------------------------------
    # KITTY
    # -----------------------------------------------------------------------
    kitty = {
      enable   = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 11;
      };
      settings = {
        foreground            = "#cdd6f4";
        background            = "#1e1e2e";
        selection_foreground  = "#1e1e2e";
        selection_background  = "#f5e0dc";
        cursor                = "#f5e0dc";
        cursor_text_color     = "#1e1e2e";
        url_color             = "#f5e0dc";
        active_tab_foreground   = "#11111b";
        active_tab_background   = "#cba6f7";
        inactive_tab_foreground = "#cdd6f4";
        inactive_tab_background = "#181825";
        color0  = "#45475a"; color1  = "#f38ba8";
        color2  = "#a6e3a1"; color3  = "#f9e2af";
        color4  = "#89b4fa"; color5  = "#f5c2e7";
        color6  = "#94e2d5"; color7  = "#bac2de";
        color8  = "#585b70"; color9  = "#f38ba8";
        color10 = "#a6e3a1"; color11 = "#f9e2af";
        color12 = "#89b4fa"; color13 = "#f5c2e7";
        color14 = "#94e2d5"; color15 = "#a6adc8";
        window_padding_width   = 10;
        cursor_shape           = "beam";
        cursor_blink_interval  = "0.5";
        scrollback_lines       = 10000;
        repaint_delay          = 10;
        input_delay            = 3;
        background_opacity     = "0.95";
        tab_bar_edge           = "bottom";
        tab_bar_style          = "fade";
        enable_audio_bell      = false;
        visual_bell_duration   = "0.1";
        remember_window_size   = false;
        initial_window_width   = "1200";
        initial_window_height  = "750";
      };
    };

  }; # end programs

  # =========================================================================
  # SERVİSLER
  # =========================================================================

  services = {

    # -----------------------------------------------------------------------
    # HYPRIDLE
    # -----------------------------------------------------------------------
    hypridle = {
      enable   = true;
      settings = {
        general = {
          before_sleep_cmd    = "hyprlock";
          after_sleep_cmd     = "hyprctl dispatch dpms on";
          lock_cmd            = "pidof hyprlock || hyprlock";
          ignore_dbus_inhibit  = false;
        };
        listener = [
          {
            timeout    = 300;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume  = "hyprctl dispatch dpms on";
          }
          {
            timeout    = 600;
            on-timeout = "pidof hyprlock || hyprlock";
          }
          {
            timeout    = 900;
            on-timeout = "pidof hyprlock || hyprlock; systemctl suspend";
          }
        ];
      };
    };

  }; # end services


  # =========================================================================
  # SYSTEMD USER SERVİSLERİ
  # =========================================================================

  # -------------------------------------------------------------------------
  # SWWW-DAEMON — Systemd User Service
  # FIX [YENİ]: swww-daemon daha önce hyprland.conf'ta exec-once ile
  # başlatılıyordu. Bu Hyprland'ın kendisine bağımlı bir süreç, systemd
  # tarafından bilinmiyor ve restart politikası yok.
  #
  # Systemd user service olarak tanımlamak şu avantajları sağlar:
  #   - Restart=on-failure: çökerse otomatik yeniden başlar
  #   - waypaper-random timer artık gerçek bir Requires bağımlılığına sahip
  #   - journalctl --user -u swww-daemon ile log takibi mümkün
  # -------------------------------------------------------------------------
  systemd.user.services.swww-daemon = {
    Unit = {
      Description = "swww wallpaper daemon";
      Documentation = "https://github.com/LGFae/swww";
      # graphical-session.target: Hyprland oturumu hazır olana kadar bekle.
      After   = [ "graphical-session.target" ];
      PartOf  = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart    = "${pkgs.swww}/bin/swww-daemon";
      # Çökerse 3 saniye bekleyip yeniden başlat.
      Restart      = "on-failure";
      RestartSec   = "3s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # -------------------------------------------------------------------------
  # WAYPAPER-RANDOM — Rastgele duvar kağıdı değiştirici
  # FIX [YENİ]: Artık swww-daemon gerçek bir systemd servis olduğu için
  # Requires ve After bağımlılıkları doğru çalışır.
  # waypaper --random çalışmadan önce swww-daemon'un hazır olmasını bekler.
  # -------------------------------------------------------------------------
  systemd.user.services.waypaper-random = {
    Unit = {
      Description = "Random wallpaper changer";
      After    = [ "graphical-session.target" "swww-daemon.service" ];
      # Requires: swww-daemon başarısız olursa waypaper-random da başlamaz.
      Requires = [ "swww-daemon.service" ];
      PartOf   = [ "graphical-session.target" ];
    };
    Service = {
      Type      = "oneshot";
      ExecStart = "${pkgs.waypaper}/bin/waypaper --random";
    };
  };

  systemd.user.timers.waypaper-random = {
    Unit.Description = "Random wallpaper changer timer";
    Timer = {
      OnActiveSec     = "5min";
      OnUnitActiveSec = "5min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # =========================================================================
  # PAKETLER
  # =========================================================================

  home.packages = with pkgs; [
    fd
    ripgrep
    jq
    wget
    curl
    file
    tree
    playerctl
    pamixer
    hyprpicker
    wev
  ];

}

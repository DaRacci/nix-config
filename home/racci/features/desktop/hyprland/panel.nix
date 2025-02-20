{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [ networkmanagerapplet ];

  wayland.windowManager.hyprland = {
    settings =
      let
        waybarBin = lib.getExe config.programs.waybar.package;
      in
      {
        exec-once = [ "${waybarBin}" ];

        bind = [ "CONTROL,ESCAPE,exec,killall waybar || ${waybarBin}" ];

        # windowrulev2 = [
        #   "float,class:^(pavucontrol)$"
        #   "size 900 450,class:^(pavucontrol)$"
        #   "move 1660 48,class:^(pavucontrol)$"
        #   "animation slide right,class:^(pavucontrol)$"
        # ];
      };
  };

  services = {
    blueman-applet.enable = true;
  };

  programs.waybar = {
    enable = false;
    package = pkgs.waybar;

    settings =
      let
        wpctl = "${pkgs.wireplumber}/bin/wpctl";
      in
      {
        mainBar = {
          layer = "top";
          position = "top";
          mod = "dock";
          height = 48;
          exclusive = true;
          passthrough = false;
          gtk-layer-shell = true;

          modules-left = [
            "custom/padd"
            "custom/l_end"
            ""
            "custom/r_end"
            "custom/l_end"
            "wlr/taskbar"
            "custom/r_end"
            ""
            "custom/padd"
          ];
          modules-center = [
            "custom/padd"
            "custom/l_end"
            "clock"
            "custom/r_end"
            "custom/padd"
          ];
          modules-right = [
            "custom/padd"
            "custom/l_end"
            "tray"
            "custom/r_end"
            "custom/l_end"
            "network"
            "bluetooth"
            "pulseaudio#sink"
            "pulseaudio#source"
            "custom/notification"
            "custom/r_end"
            "custom/padd"
          ];

          "hyprland/workspaces" = {
            format = "{id}:{delim}{clients}";
            all-outputs = true;
            active-only = false;
            on-click = "activate";
            persistent-workspaces = { };

            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
          };

          "hyprland/window" = {
            format = "{}";
            separate-outputs = true;
            rewrite = {
              "\${USER}@\${set_sysname}:(.*)" = "$1 ";
              "(.*) — Mozilla Firefox" = "$1 󰈹";
              "(.*)Mozilla Firefox" = "Firefox 󰈹";
              "(.*) - Visual Studio Code" = "$1 󰨞";
              "(.*)Visual Studio Code" = "Code 󰨞";
              "(.*) — Dolphin" = "$1 󰉋";
              "(.*)Spotify" = "Spotify 󰓇";
              "(.*)Steam" = "Steam 󰓓";
            };
            max-length = 1000;
          };

          bluetooth = {
            format = " {}";
            format-disabled = " {}";
            format-connected = " {num_connections}";
            format-connected-battery = "{icon} {device_alias} {num_connections}";
            format-icons = [
              "󰥇"
              "󰤾"
              "󰤿"
              "󰥀"
              "󰥁"
              "󰥂"
              "󰥃"
              "󰥄"
              "󰥅"
              "󰥆"
              "󰥈"
            ];

            tooltip-format = ''
              {controller_alias}
              {num_connections} connected'';
            tooltip-format-connected = ''
              {controller_alias}
              {num_connections} connected

              {device_enumerate}'';
            tooltip-format-enumerate-connected = "{device_alias}";
            tooltip-format-connected-battery = "{device_alias}	{icon} {device_battery_percentage}%";

            actions = {
              # on-click = "${hdrop} -f -b ${getExe pkgs.overskride}";
            };
          };

          clock = {
            format = "{:%I:%M %p}";
            format-alt = "{:%R 󰃭 %d·%m·%y}}";
            tooltip-format = "<tt>{calendar}</tt>";
            calendar = {
              mode = "month";
              mode-mon-col = 3;
              on-scroll = 1;
              on-click-right = "mode";
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b>{}</b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-click-forward = "tz_up";
              on-click-backward = "tz_down";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          mpris = {
            # format = "{player_icon} {dynamic}";
            # format-paused = "{status_icon} <i>{dynamic}</i>";
            player-icons = {
              default = "▶";
              mpv = "🎵";
            };
            status-icons = {
              paused = "⏸";
            };
            max-length = 60;
            interval = 1;
          };

          network = {
            tooltip = true;
            format-wifi = " ";
            format-ethernet = "󰈀 ";
            tooltip-format = ''
              Network: <big><b>{essid}</b></big>
              Signal strength: <b>{signaldBm}dBm ({signalStrength}%)</b>
              Frequency: <b>{frequency}MHz</b>
              Interface: <b>{ifname}</b>
              IP: <b>{ipaddr}/{cidr}</b>
              Gateway: <b>{gwaddr}</b>
              Netmask: <b>{netmask}</b>'';
            format-linked = "󰈀 {ifname} (No IP)";
            format-disconnected = "󰖪 ";
            tooltip-format-disconnected = "Disconnected";
            format-alt = "<span foreground='#99ffdd'> {bandwidthDownBytes}</span> <span foreground='#ffcc66'> {bandwidthUpBytes}</span>";
            interval = 1;
          };

          "pulseaudio#sink" = {
            format = "{icon} {volume}%";
            format-muted = " {volume}%";
            format-icons = [
              ""
              ""
              ""
            ];

            format-bluetooth = "{icon} {volume}%";
            format-bluetooth-muted = "";

            on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
            on-click-middle = "${lib.getExe pkgs.pavucontrol} -t 3";
            on-scroll-up = "${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
            on-scroll-down = "${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-";

            max-volume = 150;
            scroll-step = 5;
            tooltip = false;
          };

          "pulseaudio#source" = {
            format = "{format_source}";
            format-source = "{volume}%";
            format-source-muted = "‎{volume}%";

            on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            on-click-middle = "${lib.getExe pkgs.pavucontrol} -t 4";
            on-scroll-up = "${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 5%+";
            on-scroll-down = "${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 5%-";

            max-volume = 150;
            scroll-step = 5;
            tooltip = false;
          };

          "custom/weather" = {
            format = "{} °";
            tooltip = true;
            interval = 3600;
            exec = "${lib.getExe pkgs.wttrbar}";
            return-type = "json";
          };

          "wlr/taskbar" = {
            format = "{icon}";
            icon-size = "\${i_task}";
            icon-theme = "\${i_theme}";
            spacing = 0;
            tooltip-format = "{title}";
            on-click = "activate";
            on-click-middle = "close";
            ignore-list = [ "Alacritty" ];
            app_ids-mapping = {
              firefoxdeveloperedition = "firefox-developer-edition";
            };
          };

          tray = {
            icon-size = "\${i_size}";
            spacing = 5;
          };

          "custom/notification" =
            let
              swaync = lib.getExe' pkgs.swaynotificationcenter "swaync-client";
            in
            {
              tooltip = false;
              format = "{icon}";
              format-icons = {
                notification = " <span foreground='red'><sup></sup></span>";
                none = " ";
                dnd-notification = " <span foreground='red'><sup></sup></span>";
                dnd-none = " ";
                inhibited-notification = " <span foreground='red'><sup></sup></span>";
                inhibited-none = " ";
                dnd-inhibited-notification = " <span foreground='red'><sup></sup></span>";
                dnd-inhibited-none = ";";
              };
              return-type = "json";
              exec-if = "which ${swaync}";
              exec = "${swaync} -swb";
              on-click = "${swaync} -t -sw";
              on-click-right = "${swaync} -d -sw";
              escape = true;
            };

          "custom/l_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/r_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/sl_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/sr_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/rl_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/rr_end" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };

          "custom/padd" = {
            format = "  ";
            interval = "once";
            tooltip = false;
          };
        };
      };

    style = ''
      @define-color bar-bg rgba(0, 0, 0, 0);

      @define-color wb-act-bg #a6adc8;
      @define-color wb-act-fg #313244;

      @define-color wb-hvr-bg #f5c2e7;
      @define-color wb-hvr-fg #313244;

      * {
        border: none;
        border-radius: 0px;
        font-family: "JetBrainsMono Nerd Font";
        font-weight: bold;
        font-size: 16px;
        min-height: 10px;
      }

      window#waybar {
        background: @theme_base_color;
        border-bottom: 1px solid @unfocused_borders;
        color: @theme_text_color;
      }

      tooltip {
        background: @theme_base_color;
        border-radius: 8px;
        border-width: 0px;
      }

      #pulseaudio.source.source-muted,
      #pulseaudio.sink.muted {
        color: #ffcc66;
      }
      #pulseaudio.source.muted,
      #pulseaudio.sink.source-muted {
        color: @theme_text_color;
      }

      #workspaces button {
        box-shadow: none;
        text-shadow: none;
        padding: 0px;
        border-radius: 8px;
        margin-top: 4px;
        margin-bottom: 4px;
        margin-left: 0px;
        padding-left: 4px;
        padding-right: 4px;
        margin-right: 0px;
        animation: ws_normal 20s ease-in-out 1;
      }

      #workspaces button.active {
        background: @wb-act-bg;
        color: @wb-act-fg;
        margin-left: 3px;
        padding-left: 12px;
        padding-right: 12px;
        margin-right: 3px;
        animation: ws_active 20s ease-in-out 1;
        transition: all 0.4s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #workspaces button:hover {
        background: @wb-hvr-bg;
        color: @wb-hvr-fg;
        animation: ws_hover 20s ease-in-out 1;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #taskbar button {
        box-shadow: none;
        text-shadow: none;
        padding: 0px;
        border-radius: 9px;
        margin-top: 3px;
        margin-bottom: 3px;
        margin-left: 0px;
        padding-left: 3px;
        padding-right: 3px;
        margin-right: 0px;
        color: @wb-color;
        animation: tb_normal 20s ease-in-out 1;
      }

      #taskbar button.active {
        background: @wb-act-bg;
        color: @wb-act-color;
        margin-left: 3px;
        padding-left: 12px;
        padding-right: 12px;
        margin-right: 3px;
        animation: tb_active 20s ease-in-out 1;
        transition: all 0.4s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #taskbar button:hover {
        background: @wb-hvr-bg;
        color: @wb-hvr-color;
        animation: tb_hover 20s ease-in-out 1;
        transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
      }

      #backlight,
      #battery,
      #bluetooth,
      #clock,
      #cpu,
      #language,
      #memory,
      #mpris,
      #network,
      #pulseaudio,
      #notification,
      #tray,
      #window,
      #workspaces,
      #custom-l_end,
      #custom-r_end,
      #custom-sl_end,
      #custom-sr_end,
      #custom-rl_end,
      #custom-rr_end {
        opacity: 1;
        margin: 4px 0px 4px 0px;
        padding-left: 4px;
        padding-right: 4px;
      }

      #workspaces,
      #taskbar {
        padding: 0px;
      }

      #custom-r_end {
        border-radius: 0px 21px 21px 0px;
        margin-right: 9px;
        padding-right: 3px;
      }

      #custom-l_end {
        border-radius: 21px 0px 0px 21px;
        margin-left: 9px;
        padding-left: 3px;
      }

      #custom-sr_end {
        border-radius: 0px;
        margin-right: 9px;
        padding-right: 3px;
      }

      #custom-sl_end {
        border-radius: 0px;
        margin-left: 9px;
        padding-left: 3px;
      }

      #custom-rr_end {
        border-radius: 0px 7px 7px 0px;
        margin-right: 9px;
        padding-right: 3px;
      }

      #custom-rl_end {
        border-radius: 7px 0px 0px 7px;
        margin-left: 9px;
        padding-left: 3px;
      }
    '';
  };

  xdg.configFile."hyprland-autorename-workspaces".text = ''
    version = "1.1.13"

    [format]
    dedup = true
    dedup_inactive_fullscreen = false
    delim = " "
    client = "{icon}{delim}"
    client_active = "<span color='red'>{icon}</span>"
    workspace = "<b><span color='red'>{id}-{name}:</span></b>{delim}{clients}"
    workspace_empty = "<b><span color='yellow'>{id}-{name}:</span></b>{delim}{clients}"
    client_dup = "{icon}{counter_sup}{delim}"
    client_dup_fullscreen = "[{icon}]{delim}{icon}{counter_unfocused_sup}"
    client_fullscreen = "[{icon}]{delim}"

    [class_active]
    DEFAULT="{icon}"
    "(?i)firefox" = "<span color='orange'> {class}</span>"

    # [initial_class]
    # "DEFAULT" = " {class}: {title}"
    # "(?i)Kitty" = "term"

    # [initial_class_active]
    # "(?i)Kitty" = "*TERM*"

    # regex captures support is supported
    [title_in_class."(?i)foot"]
    "emerge: (.+?/.+?)-.*" = "{match1}"

    [initial_title_in_class."kitty"]
    "zsh" = "Zsh"

    [title_in_class."(firefox|chrom.*)"]
    "(?i)youtube" = "ꟳ"
    "(?i)twitch" = "ꟳ"

    [title_active."(firefox|chrom.*)"]
    "(?i)twitch" = "<span color='purple'>{icon}</span>"

    # [title_in_initial_class."(?i)kitty"]
    # "(?i)neomutt" = "neomutt"

    # [initial_title_in_initial_class."(?i)kitty"]
    # "(?i)neomutt" = "neomutt"

    # [initial_title."(?i)kitty"]
    # "zsh" = "Zsh"

    # [initial_title_active."(?i)kitty"]
    # "zsh" = "*Zsh*"

    [workspaces_name]
    0 = "zero"
    1 = "one"
    2 = "two"
    3 = "three"
    4 = "four"
    5 = "five"
    6 = "six"
    7 = "seven"
    8 = "eight"
    9 = "nine"
    10 = "ten"

    [class]
    DEFAULT = ""
    "(?i)firefox" = "<span color='orange'> </span>"
    "(?i)kitty" = ""
    "(?i)alacritty" = ""
    bleachbit = ""
    burp-startburp = ""
    calibre-gui = ""
    "chrome-faolnafnngnfdaknnbpnkhgohbobgegn-default" = ""
    chromium = ""
    "Gimp-2.10" = ""
    code-oss = ""
    cssh = ""
    darktable = ""
    discord = ""
    dmenu-clipboard = ""
    dmenu-pass = ""
    duolingo = ""
    element = ""
    fontforge = ""
    gcr-prompter = ""
    gsimplecalc = ""
    "jetbrains-studio" = ""
    "kak" = ""
    kicad = ""
    "(?i)waydroid.*" = "droid"
    obsidian = ""
    "dmenu-emoji" = ""
    "dmenu-browser" = ""
    "dmenu-pass generator" = ""
    "qalculate-gtk" = ""
    krita = ""
    libreoffice-calc = ""
    libreoffice-impress = ""
    libreoffice-startcenter = ""
    libreoffice-writer = ""
    molotov = ""
    mpv = ""
    neomutt = ""
    nm-connection-editor = ""
    org-ksnip-ksnip = ""
    org-pwmt-zathura = ""
    org-qutebrowser-qutebrowser = ""
    org-telegram-desktop = ""
    paperwork = ""
    pavucontrol = ""
    personal = ""
    plexamp = ""
    qutepreview = ""
    rapid-photo-downloader = ""
    remote-viewer = ""
    sandboxed-tor-browser = ""
    scli = ""
    shopping = ""
    Signal = ""
    slack = ""
    snappergui = ""
    songrec = ""
    spotify = ""
    steam = ""
    streamlink-twitch-gui = ""
    sun-awt-x11-xframepeer = ""
    swappy = ""
    taskwarrior-tui = ""
    telegramdesktop = ""
    ".*transmission.*" = ""
    udiskie = ""
    vimiv = ""
    virt-manager = ""
    vlc = ""
    vncviewer = ""
    wayvnc = "󰀄"
    whatsapp-desktop = ""
    whatsapp-nativefier-d52542 = ""
    wire = "󰁀"
    wireshark-gtk = ""
    wlfreerdp = "󰀄"
    work = ""
    xplr = ""
    nemo = ""
    zoom = ""

    [exclude]
    "" = "^$" # prevent displaying clients with empty class
  '';
}

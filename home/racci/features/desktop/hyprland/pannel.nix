{ pkgs, ... }: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        mod = "dock";
        height = 48;
        exclusive = true;
        passthrough = false;
        gtk-layer-shell = true;

        # modules-left = [ "hyprland/workspaces" "sway/mode" "wlr/taskbar" ];
        # modules-center = [ "hyprland/window" ];
        # modules-right = [ "mpd" "temperature" ];

        modules-left = [ "custom/padd" "custom/l_end" "custom/cliphist" "idle_inhibitor" "custom/r_end" "custom/l_end" "wlr/taskbar" "custom/r_end" "" "custom/padd" ];
        modules-center = [ "custom/padd" "custom/l_end" "mpris" "custom/r_end" "custom/l_end" "clock" "custom/r_end" "custom/padd" ];
        modules-right = [ "custom/padd" "custom/l_end" "tray" "custom/r_end" "custom/l_end" "network" "bluetooth" "wireplumber" "wireplumber#microphone" "custom/r_end" "custom/padd" ];

        "hyprland/workspaces" = {
          format = "{icon}";
          all-outputs = true;
          active-only = false;
          on-click = "activate";
          persistent-workspaces = { };
          # on-scroll-up = "hyprctl dispatch workspace e+1";
          # on-scroll-down = "hyprctl dispatch workspace e-1";
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
          format-icons = [ "󰥇" "󰤾" "󰤿" "󰥀" "󰥁" "󰥂" "󰥃" "󰥄" "󰥅" "󰥆" "󰥈" ];

          tooltip-format = "{controller_alias}\n{num_connections} connected";
          tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n\n{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          tooltip-format-connected-battery = "{device_alias}\t{icon} {device_battery_percentage}%";
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

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "󰥔";
            deactivated = "";
          };
        };

        mpris = {
          format = "{player_icon} {dynamic}";
          format-paused = "{status_icon} <i>{dynamic}</i>";
          player-icons = {
            default = "▶";
            mpv = "🎵";
          };
          status-icons = {
            paused = "⏸";
          };
          max-length = 1000;
          interval = 1;
        };

        network = {
          tooltip = true;
          format-wifi = " ";
          format-ethernet = "󰈀 ";
          tooltip-format = "Network: <big><b>{essid}</b></big>\nSignal strength: <b>{signaldBm}dBm ({signalStrength}%)</b>\nFrequency: <b>{frequency}MHz</b>\nInterface: <b>{ifname}</b>\nIP: <b>{ipaddr}/{cidr}</b>\nGateway: <b>{gwaddr}</b>\nNetmask: <b>{netmask}</b>";
          format-linked = "󰈀 {ifname} (No IP)";
          format-disconnected = "󰖪 ";
          tooltip-format-disconnected = "Disconnected";
          format-alt = "<span foreground='#99ffdd'> {bandwidthDownBytes}</span> <span foreground='#ffcc66'> {bandwidthUpBytes}</span>";
          interval = 2;
        };

        wireplumber = {
          format = "{icon} {volume}%";
          format-muted = "";
          format-icons = [ "" "" "" ];
          
          # on-click = "pavucontrol -t 3";
          # on-click-middle = "${ScrDir}/volumecontrol.sh -o m";
          # on-scroll-up = "${ScrDir}/volumecontrol.sh -o i";
          # on-scroll-down = "${ScrDir}/volumecontrol.sh -o d";
          
          tooltip-format = "{icon} {desc} // {volume}%";
          max-volume = 100;
          scroll-step = 5;
        };

        "wireplumber#microphone" = {        
          format = "{format_source}";
          format-source = "";
          format-source-muted = "";

          # on-click = "pavucontrol -t 4";
          # on-click-middle = "${ScrDir}/volumecontrol.sh -i m";
          # on-scroll-up = "${ScrDir}/volumecontrol.sh -i i";
          # on-scroll-down = "${ScrDir}/volumecontrol.sh -i d";

          tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          scroll-step = 5;
        };

        "custom/cliphist" = {
          format = "{}";
          exec = "echo; echo 󰅇 clipboard history";
          # on-click = "sleep 0.1 && ${sSrcDir}/cliphist.sh c";
          # on-click-right = "sleep 0.1 && ${sSrcDir}/cliphist.sh d";
          # on-click-middle = "sleep 0.1 && ${sSrcDir}/cliphist.sh w";
          interval = 86400;
          tooltip = true;
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

        "custom/l_end" = {
          format = " ";
          interval = "once";
          tooltip = false;
        };

        "custom/r_end" ={
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

        # "custom/wallpaper-change" = {
        #   format = "{}";
        # };
      };
    };

    style = ''
      @define-color bar-bg rgba(0, 0, 0, 0);

      @define-color main-bg #11111b;
      @define-color main-fg #cdd6f4;

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
        background: @bar-bg;
      }

      tooltip {
        background: @main-bg;
        color: @main-fg;
        border-radius: 8px;
        border-width: 0px;
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
        color: @main-fg;
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
      #custom-cliphist,
      #clock,
      #custom-cpuinfo,
      #cpu,
      #custom-gpuinfo,
      #idle_inhibitor,
      #custom-keybindhint,
      #language,
      #memory,
      #mpris,
      #network,
      #custom-power,
      #pulseaudio,
      #custom-spotify,
      #taskbar,
      #custom-theme,
      #tray,
      #custom-updates,
      #custom-wallchange,
      #custom-wbar,
      #window,
      #workspaces,
      #custom-l_end,
      #custom-r_end,
      #custom-sl_end,
      #custom-sr_end,
      #custom-rl_end,
      #custom-rr_end {
        color: @main-fg;
        background: @main-bg;
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
}

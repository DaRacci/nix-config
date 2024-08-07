{ config, lib, ... }: {
  services.mako = {
    enable = false;
    icons = true;
    actions = true;
    defaultTimeout = 5000;

    layer = "overlay";
    anchor = "top-center";
    width = 450;
    height = 120;
    margin = "5";
    padding = "0,5,10";
    borderSize = 0;
    borderRadius = 10;

    extraConfig = ''
      text-alignment=center
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkIf config.services.mako.enable ''
    exec-once = ${lib.getExe config.services.mako.package}
  '';

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "bottom";
      layer = "top";
      cssPriority = "application";
      control-center-margin-top = 0;
      control-center-margin-bottom = 0;
      control-center-margin-right = 0;
      control-center-margin-left = 0;
      notification-icon-size = 100;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      fit-to-screen = true;
      control-center-width = 400;
      control-center-height = 600;
      notification-window-width = 500;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      widgets = [ "title" "dnd" "notifications" "mpris" ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        label = {
          max-lines = 1;
          text = "Notification Center";
        };
        mpris = {
          image-size = 72;
          image-radius = 8;
          blur = false;
        };
        buttons-grid = {
          actions = [
            {
              label = "󰐥";
              command = "systemctl poweroff";
            }
            {
              label = "󰜉";
              command = "systemctl reboot";
            }
            {
              label = "󰌾";
              command = "$HOME/.scripts/hyprlock";
            }
            {
              label = "󰍃";
              command = "swaymsg exit";
            }
            {
              label = "󰏥";
              command = "systemctl suspend";
            }
            {
              label = "󰛳";
              command = "nm-connection-editor";
            }
            {
              label = "󰂯";
              command = "blueman-manager";
            }
            {
              label = "";
              command = "kooha";
            }
          ];
        };
      };
    };

    style = /*css*/ ''
      @define-color cc-bg rgba(0, 0, 0, 1);
      @define-color noti-border-color rgba(255, 255, 255, 0.15);
      @define-color noti-bg #24273a;
      @define-color noti-bg-darker #363a4f;
      @define-color noti-bg-hover rgb(27, 27, 43);
      @define-color noti-bg-focus rgba(27, 27, 27, 0.6);
      @define-color noti-close-bg rgba(255, 255, 255, 0.1);
      @define-color noti-close-bg-hover rgba(255, 255, 255, 0.15);
      @define-color text-color #cad3f5;

      @define-color base   #1E1D2E;
      @define-color mantle #181825;
      @define-color crust  #11111b;

      @define-color text     #cdd6f4;
      @define-color subtext0 #a6adc8;
      @define-color subtext1 #bac2de;

      @define-color surface0 #313244;
      @define-color surface1 #45475a;
      @define-color surface2 #585b70;

      @define-color overlay0 #6c7086;
      @define-color overlay1 #7f849c;
      @define-color overlay2 #9399b2;

      @define-color blue      #89b4fa;
      @define-color lavender  #b4befe;
      @define-color sapphire  #74c7ec;
      @define-color sky       #89dceb;
      @define-color teal      #94e2d5;
      @define-color green     #a6e3a1;
      @define-color yellow    #f9e2af;
      @define-color peach     #fab387;
      @define-color maroon    #eba0ac;
      @define-color red       #f38ba8;
      @define-color mauve     #cba6f7;
      @define-color pink      #f5c2e7;
      @define-color flamingo  #f2cdcd;
      @define-color rosewater #f5e0dc;

      * {
        all: unset;
        font-size: 14px;
        font-family: "SpaceMonoNerdFont";
        transition: 200ms;
      }

      .widget-mpris {
        background: linear-gradient(to right, #363a4f, rgba(183, 189, 248, 0.3));

        padding: 14px;
        border-radius: 10px;
      }

      .widget-mpris-player {
        padding: 8px;
        margin: 4px;
      }

      .widget-mpris-title {
        font-weight: 600;
        font-size: 0.75rem;
      }

      .widget-mpris-subtitle {
        font-size: 0.52rem;
      }

      .widget-buttons-grid {
        font-size: 8px;
        padding: 8px;
        margin-top: 10px;
        border-radius: 10px;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button {
        margin: 3px;
        background: #494d64;
        border-radius: 6px;
        color: #cad3f5;
      }

      .widget-buttons-grid > flowbox > flowboxchild > button:hover {
        background: #6e738d;
      }

      /* DND widget */
      .widget-dnd {
          margin: 8px;
          font-size: 1.1rem;
      }
      .widget-dnd > switch {
          font-size: initial;
          border-radius: 4px;
          background: @base;
          /* background: @theme_bg_color; */
          /* border: 1px solid @surface1; */
      }
      .widget-dnd > switch:checked {
          background: @insensitive_base_color;
      }

      .widget-dnd > switch slider {
          background: @base;
          /* background: @theme_bg_color; */
          border-radius: 12px;
      }


      .floating-notifications.background .notification-row .notification-background {
        box-shadow:
          0 0 8px 0 rgba(0, 0, 0, 0.8),
          inset 0 0 0 1px #363a4f;
        border-radius: 10px;
        margin: 18px;
        background-color: #24273a;
        color: #cad3f5;
        border: 2px solid rgba(183, 189, 248, 0.5);
        padding: 0;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification {
        padding: 7px;
        border-radius: 10px;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification.critical {
        box-shadow: inset 0 0 7px 0 #ed8796;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        .notification-content {
        margin: 7px;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        .notification-content
        .summary {
        color: #cad3f5;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        .notification-content
        .time {
        color: #a5adcb;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        .notification-content
        .body {
        color: #cad3f5;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > * {
        min-height: 1.4em;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action {
        border-radius: 7px;
        color: #cad3f5;
        background-color: #363a4f;
        box-shadow: inset 0 0 0 1px #494d64;
        margin: 7px;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action:hover {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #363a4f;
        color: #cad3f5;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action:active {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #7dc4e4;
        color: #cad3f5;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .close-button {
        margin: 7px;
        padding: 2px;
        border-radius: 6.3px;
        color: #24273a;
        background-color: #ed8796;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .close-button:hover {
        background-color: #ee99a0;
        color: #24273a;
      }

      .floating-notifications.background
        .notification-row
        .notification-background
        .close-button:active {
        background-color: #ed8796;
        color: #24273a;
      }

      .control-center {
        box-shadow:
          0 0 8px 0 rgba(0, 0, 0, 0.8),
          inset 0 0 0 1px #363a4f;
        border-radius: 5px;
        margin: 12px;
        background-color: #24273a;
        color: #cad3f5;
        border: 2px solid rgba(183, 189, 248, 0.5);
        padding: 10px;
      }

      .control-center .widget-title {
        margin: 8px;
        color: #cad3f5;
        font-size: 9px;
      }

      .control-center .widget-title button {
        border-radius: 7px;
        color: #cad3f5;
        background-color: #363a4f;
        box-shadow: inset 0 0 0 1px #494d64;
        padding: 8px;
      }

      .control-center .widget-title button:hover {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #5b6078;
        color: #cad3f5;
      }

      .control-center .widget-title button:active {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #7dc4e4;
        color: #24273a;
      }

      .control-center .notification-row .notification-background {
        border-radius: 5px;
        color: #cad3f5;
        background-color: #363a4f;
        box-shadow: inset 0 0 0 1px #494d64;
        margin-top: 10px;
      }

      .control-center .notification-row .notification-background .notification {
        padding: 5px;
        border-radius: 5px;
      }

      .control-center
        .notification-row
        .notification-background
        .notification.critical {
        box-shadow: inset 0 0 7px 0 #ed8796;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        .notification-content {
        margin: 7px;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        .notification-content
        .summary {
        color: #cad3f5;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        .notification-content
        .time {
        color: #a5adcb;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        .notification-content
        .body {
        color: #cad3f5;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > * {
        min-height: 3.4em;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action {
        border-radius: 0px;
        color: #cad3f5;
        background-color: #494d64;
        box-shadow: inset 0 0 0 1px #494d64;
        margin: 4px;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action:hover {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #5b6078;
        color: #cad3f5;
      }

      .control-center
        .notification-row
        .notification-background
        .notification
        > *:last-child
        > *
        .notification-action:active {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #7dc4e4;
        color: #cad3f5;
      }

      .control-center .notification-row .notification-background .close-button {
        margin: 3px;
        padding: 2px;
        border-radius: 6.3px;
        color: #24273a;
        background-color: #ee99a0;
      }

      .control-center .notification-row .notification-background .close-button:hover {
        background-color: #ed8796;
        color: #24273a;
      }

      .control-center
        .notification-row
        .notification-background
        .close-button:active {
        background-color: #ed8796;
        color: #24273a;
      }

      .control-center .notification-row .notification-background:hover {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #8087a2;
        color: #cad3f5;
      }

      .control-center .notification-row .notification-background:active {
        box-shadow: inset 0 0 0 1px #494d64;
        background-color: #7dc4e4;
        color: #cad3f5;
      }

      .notification-row
        .notification-background
        .notification
        .notification-default-action
        .notification-content
        .image {
        /* Notification Primary Image */
        -gtk-icon-effect: none;
        border-radius: 4px;
        /* Size in px */
        margin: 4px;
        margin-right: 20px;
      }

      /* Mpris widget */
      .widget-mpris {
          padding: 5px;
          padding-bottom: 0px;
          margin-bottom: 0px;
      }
      .widget-mpris > box {
          padding: 0px;
          margin: 1px 1px -12px 1px;
          padding: 0px;
          border-radius: 4px;
          background: alpha(@mantle, 0.2);
      }
    '';
  };
}




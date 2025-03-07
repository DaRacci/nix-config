{ config, lib, ... }:
{
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
    enable = false;
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
      widgets = [
        "title"
        "dnd"
        "notifications"
        "mpris"
      ];
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
  };
}

{ config, pkgs, lib, ... }:
let
  inherit (lib) getExe;
in
{
  home.packages = with pkgs; [ unstable.hyprlock unstable.hypridle ];

  wayland.windowManager.hyprland.settings = {
    exec = [
      "pidof hypridle || ${getExe pkgs.hypridle}"
    ];
  };

  xdg.configFile."hypr/hyprlock.conf".text = ''
    $text_color = rgba(FFFFFFFF)
    $entry_background_color = rgba(33333311)
    $entry_border_color = rgba(3B3B3B55)
    $entry_color = rgba(FFFFFFFF)
    $font_family = JetBrainsMono Nerd Font
    $font_family_clock = JetBrainsMono Nerd Font
    $font_material_symbols = Material Symbols Rounded

    background {
        # color = rgba(170C04FF)
        color = rgba(000000FF)
        # path = {{ SWWW_WALL }}
        # path = screenshot
        # blur_size = 5
        # blur_passes = 4
    }
    input-field {
        monitor =
        size = 250, 50
        outline_thickness = 2
        dots_size = 0.1
        dots_spacing = 0.3
        outer_color = $entry_border_color
        inner_color = $entry_background_color
        font_color = $entry_color
        # fade_on_empty = true

        position = 0, 20
        halign = center
        valign = center
    }

    label { # Clock
        monitor =
        text = $TIME
        shadow_passes = 1
        shadow_boost = 0.5
        color = $text_color
        font_size = 65
        font_family = $font_family_clock

        position = 0, 300
        halign = center
        valign = center
    }
    label { # Greeting
        monitor =
        text = hi $USER !!!
        shadow_passes = 1
        shadow_boost = 0.5
        color = $text_color
        font_size = 20
        font_family = $font_family

        position = 0, 240
        halign = center
        valign = center
    }
    label { # lock icon
        monitor =
        text = lock
        shadow_passes = 1
        shadow_boost = 0.5
        color = $text_color
        font_size = 21
        font_family = $font_material_symbols

        position = 0, 65
        halign = center
        valign = bottom
    }
    label { # "locked" text
        monitor =
        text = locked
        shadow_passes = 1
        shadow_boost = 0.5
        color = $text_color
        font_size = 14
        font_family = $font_family

        position = 0, 45
        halign = center
        valign = bottom
    }

    label { # Status
        monitor =
        text = cmd[update:5000] ~/.config/hypr/hyprlock/status.sh
        shadow_passes = 1
        shadow_boost = 0.5
        color = $text_color
        font_size = 14
        font_family = $font_family

        position = 30, -30
        halign = left
        valign = top
    }
  '';

  xdg.configFile."hypr/hyperidle.conf".text =
    let
      hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
      lockCmd = "pidof hyprlock || ${getExe pkgs.hyprlock}";
      suspendCmd = "pidof steam || systemctl suspend || loginctl suspend";
      brightnessctl = "${getExe pkgs.brightnessctl}";
    in
    ''
      general {
        lock_cmd = ${lockCmd}
        before_sleep_cmd = ${suspendCmd}
        after_sleep_cmd = ${hyprctl} dispatch dpms on
      }

      listener {
        timeout = 180 # 3 minutes
        on-timeout = ${brightnessctl} -sd rgb:kbd_backlight set 0
        on-resume = ${brightnessctl} -rd rgb:kbd_backlight
      }

      listener {
        timeout = 300 # 5 minutes
        on-timeout = loginctl lock-session
      }

      listener {
        timeout = 420 # 7 minutes
        on-timeout = ${hyprctl} dispatch dpms off
        on-resume = ${hyprctl} dispatch dpms on
      }

      listener {
        timeout = 1800 # 30 minutes
        on-timeout = ${suspendCmd}
      }
    '';
}

{ pkgs, lib, ... }: {
  home.packages = with pkgs; [ unstable.hyprlock unstable.hypridle ];

  xdg.configFile."hypr/hyprlock.conf".text = ''
    $text_color = rgba(ede0deFF)
    $entry_background_color = rgba(130F0F11)
    $entry_border_color = rgba(a08c8955)
    $entry_color = rgba(d8c2bfFF)
    $font_family = Gabarito
    $font_family_clock = Gabarito
    $font_material_symbols = Material Symbols Rounded

    background {
        color = rgba(130F0F77)
        # path = {{ SWWW_WALL }}
        path = screenshot
        blur_size = 5
        blur_passes = 4
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
        color = $text_color
        font_size = 14
        font_family = $font_family

        position = 0, 50
        halign = center
        valign = bottom
    }

    label { # Status
        monitor =
        text = cmd[update:5000] ~/.config/hypr/hyprlock/status.sh
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
      notifySend = "${pkgs.libnotify}/bin/notiofy-send";
    in
    ''
      general {
        lock_cmd = ${notifySend} "Locking screen..."
        unlock_cmd = ${notifySend} "Unlocking screen..."
        before_sleep_cmd = ${notifySend} "Going to sleep..."
        after_wake_cmd = ${notifySend} "Waking up..."
        ignore_dbus_inhibit = false
      }

      listener {
        timeout = 500
        on-timeout = ${notifySend} "Idle for 5 seconds..."
        on-resume = ${notifySend} "Resumed from idle..."
      }
    '';

  wayland.windowManager.hyprland.extraConfig = ''
    exec-once = ${lib.getExe pkgs.unstable.hypridle}/bin/hypridle
  '';
}

{ config, pkgs, ... }: {
  home.packages = with pkgs; [ unstable.hyprlock unstable.hypridle ];

  xdg.configFile."hypr/hyprlock.conf".text = ''
    background {
      path = ${config.home.homeDirectory}/Pictures/Wallpapers/10.png
      color = rgba(203, 53, 61, 1.0)

      # all these options are taken from hyprland, see https://wiki.hyprland.org/Configuring/Variables/#blur for explanations
      blur_passes = 1
      blur_size = 7
      noise = 0.0117
      contrast = 0.8916
      brightness = 0.8172
      vibrancy = 0.1696
      vibrancy_darkness = 0.0
    }

    input-field {
      monitor = DP-2
      size = 200, 50
      outline_thickness = 3
      dots_size = 0.33 # Scale of input-field height, 0.2 - 0.8
      dots_spacing = 0.15 # Scale of dots' absolute size, 0.0 - 1.0
      dots_center = false
      dots_rounding = -1 # -1 default circle, -2 follow input-field rounding
      outer_color = rgb(151515)
      inner_color = rgb(200, 200, 200)
      font_color = rgb(10, 10, 10)
      fade_on_empty = true
      fade_timeout = 1000 # Milliseconds before fade_on_empty is triggered.
      placeholder_text = <i>Input Password...</i> # Text rendered in the input box when it's empty.
      hide_input = false
      rounding = -1 # -1 means complete rounding (circle/oval)
      fail_color = rgb(204, 34, 34) # if authentication failed, changes outer_color and fail message color
      fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i> # can be set to empty
      fail_transition = 300 # transition time in ms between normal outer_color and fail_color

      position = 0, -20
      halign = center
      valign = center
    }

    label {
      monitor = DP-2
      text = Hi there, $USER
      color = rgba(200, 200, 200, 1.0)
      font_size = 25
      font_family = Noto Sans

      position = 0, 80
      halign = center
      valign = center
    }
  '';

  xdg.configFile."hypr/hyperidle.conf".text = let
    notifySend = "${pkgs.libnotify}/bin/notiofy-send";
  in ''
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
}
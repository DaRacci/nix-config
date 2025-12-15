{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
in
{
  custom.uwsm.sliceAllocation.background = [ "hypridle" ];

  wayland.windowManager.hyprland.custom-settings.permission.screenCopy = [
    (lib.getExe config.programs.hyprlock.package)
  ];

  programs.hyprlock = {
    enable = true;
    settings =
      let
        inherit (config) stylix;
        fontFamily = config.stylix.fonts.serif.name;
        fontSize = stylix.fonts.sizes.desktop;

        textColour = config.programs.hyprlock.settings.input-field.font_color;
      in
      {
        background = {
          blur_passes = 2;
          contrast = 1;
          brightness = 0.5;
          vibrancy = 0.2;
          vibrancy_darkness = 0.2;
          hide_cursor = false;
        };

        input-field = {
          size = "250, 50";
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.35;
          dots_center = true;
          fade_on_empty = false;
          rounding = -1;
          placeholder_text = "<i><span foreground=\"##cdd6f4\">Input Password...</span></i>";
          hide_input = false;

          position = "0, -200";
          halign = "center";
          valign = "center";
        };

        label = [
          # Date
          {
            text = "cmd[update:1000] date +'%A, %B %d'";
            shadow_passes = 1;
            shadow_boost = 0.5;
            color = textColour;
            font_size = 22;
            font_family = fontFamily;

            position = "0, 300";
            halign = "center";
            valign = "center";
          }
          # Time
          {
            text = "cmd[update:1000] date +'%-I:%M'";
            shadow_passes = 1;
            shadow_boost = 0.5;
            color = textColour;
            font_size = 95;
            font_family = "JetBrains Mono ExtraBold";

            position = "0, 200";
            halign = "center";
            valign = "center";
          }
          # User
          {
            text = "cmd[update:1000] whoami";
            color = textColour;
            font_size = fontSize;
            font_family = fontFamily;
            position = "0, -10";
            halign = "center";
            valign = "top";
          }
          # Active Media
          {
            text = "cmd[update:1000] ${lib.getExe pkgs.playerctl} metadata --format '{{title}}  {{artist}}'";
            color = textColour;
            font_size = 18;
            font_family = fontFamily;
            position = "0, 50";
            halign = "center";
            valign = "bottom";
          }
        ];

        image = [
          # Profile Picture
          {
            path = "/home/racci/Pictures/Media/Profile Pictures/James/Main.jpg";
            size = 100;
            border_size = 2;
            border_color = "$foreground";
            position = "0, -100";
            halign = "center";
            valign = "center";
          }
        ];
      };
  };

  services.hypridle = {
    enable = true;
    settings =
      let
        hyprctl = "${lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl"}";
        lockCmd = "pidof hyprlock || ${getExe pkgs.hyprlock}";
        suspendCmd = "pidof steam || systemctl suspend || loginctl suspend";
        brightnessctl = "${getExe pkgs.brightnessctl}";
      in
      {
        general = {
          lock_cmd = lockCmd;
          before_sleep_cmd = suspendCmd;
          after_sleep_cmd = "${hyprctl} dispatch dpms on";
        };

        listener = [
          {
            timeout = 180; # 3 minutes
            on-timeout = "${brightnessctl} -sd rgb:kbd_backlight set 0";
            on-resume = "${brightnessctl} -rd rgb:kbd_backlight";
          }
          {
            timeout = 300; # 5 minutes
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 420; # 7 minutes
            on-timeout = "${hyprctl} dispatch dpms off";
            on-resume = "${hyprctl} dispatch dpms on";
          }
          {
            timeout = 1800; # 30 minutes
            on-timeout = suspendCmd;
          }
        ];
      };
  };
}

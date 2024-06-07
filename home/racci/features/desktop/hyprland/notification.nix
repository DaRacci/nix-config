{ config, lib, ... }:
let inherit (config) colorScheme; in {
  services.mako = {
    enable = true;
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

    backgroundColor = "#${colorScheme.palette.base00}";
    textColor = "#${colorScheme.palette.base05}";
    borderColor = "#${colorScheme.palette.base0D}";
    progressColor = "over #313244";

    extraConfig = ''
      text-alignment=center

      [urgency=low]
      text-color=#${colorScheme.palette.base0A}

      [urgency=high]
      text-color=#${colorScheme.palette.base08}
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkIf config.services.mako.enable ''
    exec-once = ${lib.getExe config.services.mako.package}
  '';
}

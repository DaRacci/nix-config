{ config, lib, ... }: {
  programs.mako = {
    enable = true;
    actions = true;

    defaultTimeout = 5;
    anchor = "top-center";

    font = "sans-serif";

    backgroundColor = "#000000";
    borderColor = "#ffffff";
    borderRadius = 0;
    borderSize = 0;
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkIf config.services.mako.enable ''
    exec-once = ${lib.getExe config.programs.mako.package}
  '';
}

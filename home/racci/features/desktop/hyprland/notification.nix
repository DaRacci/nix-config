{ config, lib, ... }: {
  services.mako = {
    enable = true;
    actions = true;
    defaultTimeout = 5000;
    padding = "15";
    borderSize = 2;
    borderRadius = 5;
    anchor = "top-center";
    icons = true;
    # actions = true;
    backgroundColor = "#1e1e2e";
    borderColor = "#b4befe";
    progressColor = "over #313244";
    textColor = "#cdd6f4";

    extraConfig = ''
      text-alignment=center
      [urgency=high]
      border-color=#fab387
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkIf config.services.mako.enable ''
    exec-once = ${lib.getExe config.services.mako.package}
  '';
}

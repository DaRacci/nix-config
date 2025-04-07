{
  flake,
  ...
}:
{
  imports = [
    ./features/desktop/hyprland

    "${flake}/home/shared/features/games"
    "${flake}/home/shared/applications"
  ];

  user.persistence.enable = true;

  wayland.windowManager.hyprland.settings.monitor = [
    "HDMI-A-1, 2560x1440@144, auto, 1" # Integrated Graphics
  ];

  purpose = {
    enable = true;

    development = {
      enable = true;
      rust.enable = true;
    };

    gaming = {
      enable = true;
      osu.enable = true;
      steam.enable = true;
      vr.enable = true;

      modding = {
        enable = true;
        enableSatisfactory = true;
        enableBeatSaber = true;
        enableThunderstore = true;
      };

      simulator = {
        enable = true;
        enableRacing = true;
      };
    };

    modelling = {
      enable = true;
      blender.enable = false;
    };

    diy = {
      enable = true;
      printing.enable = true;
    };
  };
}

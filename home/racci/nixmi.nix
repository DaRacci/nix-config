{
  flake,
  ...
}:
{
  imports = [
    ./features/desktop/hyprland

    "${flake}/home/shared/features/games"
    "${flake}/home/shared/applications"
    "${flake}/home/shared/features/windows.nix"
  ];

  user.persistence.enable = true;

  wayland.windowManager.hyprland.settings.monitor = [
    "DP-6,      2560x1440@165,  0x0,        1, vrr, 1" # Center Monitor
    "DP-4,      2560x1440@144,  auto-left,  1, vrr, 1" # Left Monitor
    "DP-5,      2560x1440@144,  auto-right, 1, vrr, 1" # Right Monitor
    "HDMI-A-2,  2732x2048@90,   auto-right, 2"
    "HDMI-A-2,  disable" # Disable Virtual Monitor, will be managed by sunshine.
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

  programs.looking-glass-client = {
    enable = true;
    settings = {
      input = {
        captureOnFocus = false;
        autoCapture = false;
        escapeKey = "KEY_END";
      };

      win = {
        fullScreen = true;
      };
    };
  };
}

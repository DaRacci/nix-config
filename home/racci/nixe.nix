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
    "DP-2,      2560x1440@165,  0x0,        1, vrr, 1" # Center Monitor
    "DP-1,      2560x1440@144,  auto-left,  1, vrr, 1" # Left Monitor
    "DP-3,      2560x1440@144,  auto-right, 1, vrr, 1" # Right Monitor
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
      steam = {
        enable = true;
        enableNvidiaPatches = false;
      };
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

  custom = {
    audio = {
      disabledDevices = [
        # There is no mic input on a fucking DAC stupid.
        "alsa_input.pci-0000_0e_00.4.analog-stereo"

        # Disable graphics card audio / monitors
        "alsa_card.pci-0000_0b_00.1"
      ];

      updateDevices = [
        {
          name = "alsa_output.pci-0000_0e_00.4.iec958-stereo";
          props = {
            "node.nick" = "Headphones";
            "device.description" = "Starship DAC";
          };
        }
      ];
    };
  };
}

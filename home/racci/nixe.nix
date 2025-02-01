{ flake, ... }:
{
  imports = [
    ./features/desktop/hyprland

    "${flake}/home/shared/features/games"
    "${flake}/home/shared/applications"
  ];

  user.persistence.enable = true;

  purpose = {
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
        # Disable monitoring line
        "alsa_output.usb-Focusrite_Scarlett_Solo_4th_Gen_S1VXX1F360DBE3-00.analog-stereo"

        # There is no mic input on a fucking DAC stupid.
        "alsa_input.pci-0000_0e_00.4.analog-stereo"

        # Disable things that really shouldn't have built-in audio devices
        "alsa_card.usb-046d_HD_Pro_Webcam_C920_AC8BDE4F-02"
        "alsa_card.usb-Sony_Interactive_Entertainment_Wireless_Controller-00"

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

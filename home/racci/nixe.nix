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
        # Disable Instrument line and monitoring line
        "alsa_output.usb-Focusrite_Scarlett_Solo_USB-00.HiFi__hw_USB__sink"
        "alsa_input.usb-Focusrite_Scarlett_Solo_USB-00.HiFi__scarlett2i_mono_in_USB_0_1__source"

        # Disable things that really shouldn't have built-in audio devices
        "alsa_input.usb-046d_HD_Pro_Webcam_C920_AC8BDE4F-02.analog-stereo"
        "alsa_input.usb-Sony_Interactive_Entertainment_Wireless_Controller-00.analog-stereo"
        "alsa_output.usb-Sony_Interactive_Entertainment_Wireless_Controller-00.analog-surround-40"

        # Disable graphics card audio / monitors
        "alsa_output.pci-0000_0b_00.1.hdmi-stereo.2"
      ];

      updateDevices = [
        {
          node = "alsa_output.pci-0000_0e_00.4.iec958-stereo";
          props = [
            {
              name = "node.nick";
              value = "Headphones";
            }
            {
              name = "device.description";
              value = "Starship DAC";
            }
          ];
        }
      ];
    };
  };
}

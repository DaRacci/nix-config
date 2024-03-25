{ pkgs, ... }: {
  imports = [
    ./features/desktop/gnome.nix
    ./features/desktop/hyprland

    ./features/cli
    ../common/features/games
    ../common/applications
  ];

  home.packages = with pkgs.unstable; [ trayscale ];
  user.persistence.enable = true;

  purpose = {
    development = {
      enable = true;
      rust.enable = true;
    };

    gaming = {
      enable = true;
      osu.enable = true;
      steam.enable = true;

      modding = {
        enable = true;
        enableSatisfactory = true;
      };
    };

    modelling = {
      enable = true;
      blender.enable = true;
    };
  };

  custom = {
    audio = {
      disabledDevices = [
        "alsa_card.usb-046d_HD_Pro_Webcam_C920_AC8BDE4F-02"
        "alsa_card.usb-Sony_Interactive_Entertainment_Wireless_Controller-00"

        # Disable Intrument line and monitoring line
        "alsa_output.usb-Focusrite_Scarlett_Solo_USB-00.HiFi__hw_USB__sink"
        "alsa_input.usb-Focusrite_Scarlett_Solo_USB-00.HiFi__scarlett2i_mono_in_USB_0_1__source"

        # Disable graphics card audio / monitors
        # "alsa_card.pci-0000_0b_00.1"
        # "alsa_card.pci-0000_0e_00.4"
      ];
    };
  };
}

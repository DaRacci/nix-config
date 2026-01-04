{ pkgs, ... }:
{
  imports = [
    ./keyboard.nix
    ./misc.nix
    ./mobile.nix
    ./office.nix
    ./secrets.nix
    ./sync.nix
    ./theme.nix
    ./work.nix
    ./zed.nix
  ];

  xdg = {
    mimeApps.enable = true;
    configFile."gtk-3.0/bookmarks".text = ''
      file:///home/racci/Downloads Downloads
      file:///home/racci/Documents Documents
      file:///home/racci/Projects Projects
      file:///home/racci/Pictures Pictures
      file:///home/racci/Videos Videos
    '';
  };

  home.packages = with pkgs; [
    fragments
    gnome-online-accounts-gtk
    picard
  ];

  custom = {
    audio = {
      disabledDevices = [
        # Disable monitoring line
        "alsa_output.usb-Focusrite_Scarlett_Solo_4th_Gen_S1VXX1F360DBE3-00.Direct__Direct__sink"

        # Disable things that really shouldn't have built-in audio devices
        "alsa_card.usb-046d_HD_Pro_Webcam_C920_AC8BDE4F-02"
        "alsa_card.usb-Insta360_Insta360_Link_2-02"
        "alsa_input.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00"
        "alsa_card.usb-Sony_Interactive_Entertainment_Wireless_Controller-00"
      ];
    };
  };

  user.persistence.directories = [
    ".config/MusicBrainz"
  ];
}

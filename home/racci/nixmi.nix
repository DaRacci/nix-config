{
  flake,
  lib,
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

  wayland.windowManager.hyprland.settings = {
    misc.vfr = lib.mkForce false; # Monitors have brightness artifacts at different refresh rates, ultimatum is to just send all frames even if they are redundant.

    monitor = [
      "DP-6,      3840x2160@240,  0x0,        1, vrr, 1" # Center Monitor
      "DP-1,      2560x1440@144,  -2560x360,  1, vrr, 1" # Left Monitor
      "HDMI-A-1,  2560x1440@144,  3840x360,   1, vrr, 0" # Right Monitor

      "HDMI-A-2,  2732x2048@90,   auto-right, 2"
      "HDMI-A-2,  disable" # Disable Virtual Monitor, will be managed by sunshine.
    ];
  };

  custom.audio.disabledDevices = [
    "alsa_card.pci-0000_01_00.1" # Dedicated GPU
    "alsa_card.pci-0000_74_00.1" # HDMI Audio

    "alsa_input.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.analog-stereo" # Acasis Dock
    "alsa_output.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.analog-stereo" # Acasis Dock
  ];

  programs.ssh.matchBlocks = {
    "windows-work" = {
      hostname = "192.168.122.79";
      user = "AzureAD\\james@amt.com.au";
      identitiesOnly = true;
    };
  };

  purpose = {
    enable = true;

    development = {
      enable = true;
      rust.enable = true;
      dotnet.enable = true;
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
        enableNexus = true;
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

{
  self,
  ...
}:
{
  imports = [
    ./features/desktop/hyprland
    ./features/desktop/plasma
    ./features/ai.nix

    "${self}/home/shared/features/games"
    "${self}/home/shared/applications"
    "${self}/home/shared/features/windows.nix"
  ];

  user.persistence.enable = true;

  wayland.windowManager.hyprland.extraConfig = ''
    monitorv2 {
      output = DP-6
      mode = 3840x2160@240
      position = 0x0
      scale = 1
      vrr = true

      bitdepth = 10
      supports_wide_color = true
      supports_hdr = true
      sdr_min_luminance = 0.005
      sdr_max_luminance = 350
    }
    monitorv2 {
      output = DP-1
      mode = 2560x1440@144
      position = -2560x360
      scale = 1
      vrr = true
    }
    monitorv2 {
      output = HDMI-A-1
      mode = 2560x1440@120
      position = 3840x360
      scale = 1
      vrr = false
    }
  '';
  custom.audio = {
    disabledDevices = [
      "alsa_card.pci-0000_01_00.1" # Dedicated GPU
      "alsa_card.pci-0000_74_00.1" # HDMI Audio
      "alsa_card.usb-Generic_USB_Audio-00"

      "alsa_input.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.*" # Acasis Dock
      "alsa_output.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.*" # Acasis Dock
    ];

    updateDevices = {
      "alsa_output.usb-SMSL_SMSL_SU8_USB2.0-00.*" = {
        "session.suspend-timeout-seconds" = 0;
      };
    };
  };

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

      editors = {
        ai.enable = true;
        vscode.enable = true;
      };
    };

    gaming = {
      enable = true;
      osu.enable = true;
      steam.enable = true;
      vr.enable = true;
      minecraft.enable = true;

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
      cad.enable = true;
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

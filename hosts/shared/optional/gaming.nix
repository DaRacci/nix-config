{
  config,
  pkgs,
  lib,
  ...
}:
{
  hardware = {
    steam-hardware.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  programs = {
    gamescope = {
      enable = true;
      package = pkgs.gamescope;
      args = [
        "-w 2560" # Upscaled from Resolution
        "-h 1440" # Upscaled from Resolution
        "-W 2560" # Real Resolution
        "-H 1440" # Real Resolution
        "-r 0" # Uncap framerate
        "--rt"
        "--adaptive-sync"
        "--fullscreen"
        "--mangoapp"
      ];
    };

    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraEnv = {
          MANGOHUD = true;
          OBS_VKCAPTURE = true;
        };

        extraArgs = "-steamos3 -steamdeck -steampal -gamepadui";
      };
      extest.enable = true;
      extraPackages = with pkgs; [
        xwayland-run
        proton-ge-bin

        # Steam logs errors about missing these, not sure for what though.
        xorg.xwininfo
        usbutils
      ];

      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
    };

    envision = {
      enable = true;
      openFirewall = true;
      package = pkgs.envision;
    };
  };

  services = {
    wivrn = {
      enable = true;
      package = pkgs.wivrn;
      openFirewall = true;
      autoStart = true;
      defaultRuntime = true;
      extraPackages = with pkgs; [
        monado-vulkan-layers
        stardust-xr-server
        stardust-xr-flatland
        stardust-xr-gravity
        stardust-xr-magnetar
        stardust-xr-phobetor
        stardust-xr-protostar
        stardust-xr-atmosphere
        stardust-xr-sphereland
        wlx-overlay-s
      ];
      monadoEnvironment = {

      };
      config = {
        enable = true;
        json = {
          scale = [
            0.75
            0.5
          ];
          bitrate = 100000000;
          encoders = [
            {
              encoder = "nvenc";
              codec = "h265";
              width = 0.5;
              height = 1;
              offset_x = 0;
              offset_y = 0;
              group = 0;
            }
            {
              encoder = "nvenc";
              codec = "h265";
              width = 0.5;
              height = 1;
              offset_x = 0.5;
              offset_y = 0;
              group = 0;
            }
          ];
          application = [ pkgs.wlx-overlay-s ];
        };
      };
    };

    monado = {
      enable = true;
      highPriority = true;
      package = pkgs.monado;
    };

    udev = {
      packages = [ pkgs.android-udev-rules ];
      extraRules = ''
        SUBSYSTEM=="sound", ACTION=="change", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ENV{SOUND_DESCRIPTION}="Wireless Controller"
        SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", TAG+="uaccess", SYMLINK+="ocuquest%n"
        SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="346e", ACTION=="add", MODE="0666", TAG+="uaccess"
      '';
    };
  };

  networking.firewall =
    let
      alvrPorts = lib.optionals config.programs.alvr.enable [
        9942 # OSC
        8082 # Web
      ];
    in
    {
      allowedUDPPorts = alvrPorts;
      allowedTCPPorts = [ 24070 ] ++ alvrPorts;
    };
}

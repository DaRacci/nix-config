{
  config,
  pkgs,
  lib,
  ...
}:
{
  custom.defaultGroups = [
    "adbusers" # For Oculus Quest ADB access
  ];

  hardware = {
    steam-hardware.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  nixpkgs.overlays = [
    (_: prev: {
      gamescope-session = prev.gamescope-session.overrideAttrs (_: {
        prePatch = ''
          substituteInPlace gamescope-session \
            --replace-fail "-w 1280 -h 800" "-w 3840 -h 2160" \
            --replace-fail "exec gamescope \\" "
            export STEAM_DISPLAY_REFRESH_LIMITS=48,240
            export STEAM_GAMESCOPE_FORCE_HDR_DEFAULT=1
            export STEAM_GAMESCOPE_FORCE_OUTPUT_TO_HDR10PQ_DEFAULT=1
            exec gamescope \\"
        '';
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    android-tools
  ];

  programs = {
    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraArgs = "-steamos3 -steamdeck -steampal -gamepadui";
        extraEnv = {
          PRESSURE_VESSEL_SYSTEMD_SCOPE = 1;
          PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES = 1;
          PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
        };
      };
      extest.enable = true;
      extraPackages = with pkgs; [
        xwayland-run

        # Steam logs errors about missing these, not sure for what though.
        xorg.xwininfo
      ];
      extraCompatPackages = [ pkgs.proton-ge-bin ];

      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  services = {
    wivrn = {
      enable = true;
      package = pkgs.wivrn;
      openFirewall = true;
      autoStart = true;
      defaultRuntime = true;
      steam.importOXRRuntimes = true;
      highPriority = true;
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
          application = [ pkgs.wayvr ];
        };
      };
    };

    udev = {
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

{ pkgs, ... }:
{
  hardware = {
    steam-hardware.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  programs.gamescope = {
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

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
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

  programs.envision = {
    enable = true;
    openFirewall = true;
    package = pkgs.envision;
  };

  services.wivrn = {
    enable = true;
    package = pkgs.wivrn;
    openFirewall = true;
    autoStart = true;
    defaultRuntime = true;
    extraPackages = [
      pkgs.monado-vulkan-layers
      pkgs.stardust-xr-server
      pkgs.stardust-xr-flatland
      pkgs.stardust-xr-gravity
      pkgs.stardust-xr-magnetar
      pkgs.stardust-xr-phobetor
      pkgs.stardust-xr-protostar
      pkgs.stardust-xr-atmosphere
      pkgs.stardust-xr-sphereland
      pkgs.wlx-overlay-s
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

  services.monado = {
    enable = true;
    highPriority = true;
    package = pkgs.monado;
  };

  services.udev = {
    packages = [ pkgs.android-udev-rules ];
    extraRules = ''
      SUBSYSTEM=="sound", ACTION=="change", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ENV{SOUND_DESCRIPTION}="Wireless Controller"
      SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", TAG+="uaccess", SYMLINK+="ocuquest%n"
      SUBSYSTEM=="tty", KERNEL=="ttyACM*", ATTRS{idVendor}=="346e", ACTION=="add", MODE="0666", TAG+="uaccess"
    '';
  };

  networking.firewall.allowedTCPPorts = [ 24070 ];
}

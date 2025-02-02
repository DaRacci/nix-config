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

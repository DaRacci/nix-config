{ pkgs, ... }: {
  hardware = {
    steam-hardware.enable = true;
    opengl = {
      enable = true;
      driSupport32Bit = true;
    };
  };

  programs.gamescope = {
    enable = true;
    package = pkgs.unstable.gamescope;
    args = [
      "-w 2560" # Upscaled from Resolution
      "-h 1440" # Upscaled from Resolution
      "-W 2560" # Real Resolution
      "-H 1440" # Real Resolution
      "-r 0" # Uncap framerate
      "--rt"
      "--adaptive-sync"
      "--xwayland-count 1"
    ];
  };

  programs.steam = {
    enable = true;
    package = pkgs.unstable.steam;
    extraPackages = with pkgs.unstable; [
      xwayland-run
      gamescope
    ];

    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="sound", ACTION=="change", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ENV{SOUND_DESCRIPTION}="Wireless Controller"
  '';

  networking.firewall.allowedTCPPorts = [ 24070 ];
}

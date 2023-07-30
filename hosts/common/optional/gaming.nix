{ pkgs, ... }: {
  programs.gamemode = {
    enable = true;

    settings = {
      general = {
        softrealtime = "on";
        inhibit_screensaver = 1;
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
    };
  };

  hardware.steam-hardware.enable = true;
  hardware.opengl.driSupport32Bit = true;

  programs.gamescope = {
    enable = true;
    package = pkgs.unstable.gamescope;
    args = [
      "-w 2560" # Upscaled from Resolution
      "-h 1440" # Upscaled from Resolution
      "-W 2560" # Real Resolution
      "-H 1440" # Real Resolution
      # "-r 0" # Uncap framerate
      "--rt"
      # "--adaptive-sync"
      "--xwayland-count 1"
    ];
  };

  programs.steam = {
    enable = true;

    remotePlay.openFirewall = true;
    gamescopeSession.enable = false;
  };
}

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
    args = [
      # "-w 1920" # Upscaled from Resolution
      # "-h 1080" # Upscaled from Resolution
      "-W 2560" # Real Resolution
      "-H 1440" # Real Resolution
      "-r 165"  # Limited Framerate
      "-o 30"   # Limited Framerate when unfocused
      # "-Y"      # Use NVIDIA Upscalingc
      "-f"      # Fullscreen on launch
    ];
  };

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraEnv = {
        # MANGOHUD = true;
      };
    };

    remotePlay.openFirewall = true;
    gamescopeSession.enable = true;
  };
}
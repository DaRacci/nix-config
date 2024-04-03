{ pkgs, ... }: {
  programs.mangohud = {
    enable = true;
    package = pkgs.unstable.mangohud;

    settings = {
      fps_limit = [ 0 60 144 165 240 ];

      gpu_stats = true;
      gpu_temp = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;
      gpu_power = true;

      cpu_stats = true;
      cpu_temp = true;
      cpu_mhz = true;
      cpu_power = true;

      vram = true;
      ram = true;

      fps = true;
      frametime = true;

      engine_version = true;
      vulkan_driver = true;
      wine = true;

      frame_timing = true;

      gamemode = true;
    };
  };
}

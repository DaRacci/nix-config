{ config, pkgs, lib, ... }: with lib; let cfg = config.purpose.gaming; in {
  imports = [
    ./modding.nix
    ./osu.nix
    ./roblox.nix
    ./simulator.nix
    ./steam.nix
    ./vr.nix
  ];

  options.purpose.gaming = {
    enable = mkEnableOption "Gaming support base.";

    controllerSupport = mkEnableOption "controller support";
  };

  config = mkIf cfg.enable {
    xdg.userDirs.extraConfig.XDG_GAME_DIR = "${config.home.homeDirectory}/Games";
    user.persistence.directories = [{ directory = "Games"; method = "symlink"; }];

    home.packages = optionals cfg.controllerSupport (with pkgs; [ dualsensectl trigger-control ]);

    programs.mangohud = {
      enable = true;
      package = pkgs.mangohud;

      settings = {
        #region PERFORMANCE
        fps_limit = [ 0 24 30 60 144 165 240 ];
        # fps_limit_method = "early";

        vsync = 1;
        gl_vsync = 0;
        #endregion

        #region VISUAL
        # GPU Information
        gpu_stats = true;
        gpu_temp = true;
        gpu_junction_temp = false;
        gpu_core_clock = true;
        gpu_mem_temp = true;
        gpu_mem_clock = true;
        gpu_power = true;
        gpu_fan = false;
        gpu_voltage = true;

        # CPU Information
        cpu_stats = true;
        cpu_temp = true;
        cpu_power = true;
        cpu_mhz = true;
        core_load = false;

        # Process IO
        io_read = true;
        io_write = true;

        # System Memory
        vram = false;
        ram = false;
        swap = false;

        # Process Memory
        procmem = true;
        procmem_shared = true;
        procmem_virt = true;

        # FPS and Frametime
        fps = true;
        frametime = true;
        frame_timing = true;

        # GPU Throttling status
        throttling_status = true;
        throttling_status_graph = false;

        # Miscellaneous information
        engine_version = true;
        engine_short_names = false;
        gpu_name = true;
        vulkan_driver = true;
        wine = true;

        # Gamescope options
        fsr = true;
        hdr = true;
        refresh_rate = true;
        #endregion

        #region Interaction
        toggle_hud = "Shift_R+F12";
        toggle_hud_position = "Shift_R+F11";
        toggle_fps_limit = "Shift_L+F1";
        toggle_logging = "Shift_L+F2";
        #endregion

        #region Logging
        # autostart_log = "";
        # log_duration = "";
        # log_interval = 0;
        output_folder = "${config.xdg.stateHome}/mangologs";
      };
    };
  };
}

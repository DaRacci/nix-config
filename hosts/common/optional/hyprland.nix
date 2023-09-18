{ pkgs, config, ... }: {
  programs.hyprland = {
    enable = true;
    nvidiaPatches = true;
    xwayland.enable = true;
    package = pkgs.unstable.hyprland.override {
      enableXWayland = config.programs.hyprland.xwayland.enable;
      enableNvidiaPatches = config.programs.hyprland.nvidiaPatches;
    };
  };
}

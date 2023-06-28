{ pkgs, config, ... }: {
  programs.hyprland = {
    enable = true;
    nvidiaPatches = true;
    package = pkgs.unstable.hyprland.override {
      enableXWayland = config.programs.hyprland.xwayland.enable;
      hidpiXWayland = config.programs.hyprland.xwayland.hidpi;
      nvidiaPatches = config.programs.hyprland.nvidiaPatches;
    };
  };
}
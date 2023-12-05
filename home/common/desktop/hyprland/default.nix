{ inputs, ... }: {
  imports = [ inputs.hyprland.homeManagerModules.default ../wayland ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemdIntegration = true;
    recommendedEnvironment = true;
    xwayland.enable = true;
    enableNvidiaPatches = false;
  };
}

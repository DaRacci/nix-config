{ inputs, pkgs, ... }: {
  imports = [ inputs.hyprland.homeManagerModules.default ../common ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemdIntegration = true;
    recommendedEnvironment = true;
    xwayland.enable = true;
    enableNvidiaPatches = false;

    # package = pkgs.unstable.hyprland.override {
    #   enableXWayland = true;
    #   enableNvidiaPatches = true;
    # };
  };

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    NIXOS_OZONE_WAYLAND = 1;
  };
}

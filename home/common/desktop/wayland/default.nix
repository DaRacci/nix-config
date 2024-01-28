{ ... }: {
  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = 1;
    NIXOS_OZONE_WAYLAND = 1;
  };
}

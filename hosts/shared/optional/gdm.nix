{ lib, ... }: {
  programs.xwayland.enable = true;

  xdg.portal = {
    enable = lib.mkForce true;
    xdgOpenUsePortal = true;
  };

  services.xserver = {
    enable = true;

    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
  };
}

{ inputs, lib, config, ... }: {
  imports = [ inputs.xremap-flake.nixosModules.default ];

  services.xremap = {
    serviceMode = "user";
    withGnome = config.services.xserver.desktopManager.gnome.enable;
    withX11 = config.services.xserver.enable;

    userId = 1000;
    userName = "racci";
  };
}
{ pkgs, ... }: {
  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
  };

  # TODO :: Globalise
  # home-manager.users.racci.home.persistence.directories = [
  #   ".config/OpenRGB"
  # ];
}
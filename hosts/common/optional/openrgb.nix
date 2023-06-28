{ pkgs, ... }: {
  services = {
    hardware.openrgb = {
      enable = true;
      motherboard = "amd";
      package = pkgs.openrgb-with-all-plugins;
    };
  };
}
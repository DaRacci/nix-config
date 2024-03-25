{ config, pkgs, ... }: {
  home.packages = [ config.services.easyeffects.package ];

  services.easyeffects = {
    enable = true;
    package = pkgs.easyeffects;
  };

  user.persistence.directories = [
    ".config/easyeffects"
  ];
}

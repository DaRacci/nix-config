{ pkgs, ... }: {
  imports = [
    ./features/cli
  ];

  custom.theme = {
    colourScheme = "tokyodark";

    cursor = {
      name = "Bibata-Modern-Ice";
      size = 32;
      package = pkgs.bibata-cursors;
    };
  };

  custom.fontProfiles = {
    enable = true;

    monospace = {
      family = "JetBrainsMono Nerd Font";
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      size = 18;
    };

    regular = {
      family = "Fira Sans";
      package = pkgs.fira;
      size = 14;
    };

    emoji = {
      family = "OpenMoji Color";
      package = pkgs.openmoji-color;
    };
  };

  # accounts.racci = {
  #   calendar = {
  #     remote = {
  #       url = "https://nextcloud.racci.dev";
  #       userName = "Racci";
  #       passwordCommand = [
  #         "cat"
  #         "${config.sops.nextcloud.password.path}"
  #       ];
  #     };
  #   };
  # };

  # sops.secrets = {
  #   nextcloud.password = { };
  # };
}

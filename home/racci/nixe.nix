{ pkgs, ... }: {
  imports = [
    ./features/desktop/gnome.nix
    ./features/desktop/hyprland

    ./features/cli
    ../common/features/games
    ../common/applications
  ];

  home.packages = with pkgs.unstable; [ trayscale ];
  user.persistence.enable = true;

  purpose = {
    development = {
      enable = true;
      rust.enable = true;
    };

    gaming = {
      enable = true;
      osu.enable = true;
      steam.enable = true;

      modding = {
        enable = true;
        enableSatisfactory = true;
      };
    };

    modelling = {
      enable = true;
      blender.enable = true;
    };
  };
}

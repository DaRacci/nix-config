{ inputs, pkgs, ... }: {
  imports = [
    ./features/cli
  ];

  stylix = {
    base16Scheme = "${inputs.tinted-theming}/base16/tokyo-night-dark.yaml";

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 32;
    };

    fonts = rec {
      emoji = {
        package = pkgs.openmoji-color;
        name = "OpenMoji Color";
      };

      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font";
      };

      sansSerif = {
        package = pkgs.fira;
        name = "Fira Sans";
      };
      serif = sansSerif;

      sizes = {
        applications = 14;
        desktop = 12;
        popups = 14;
        terminal = 18;
      };
    };
  };
}

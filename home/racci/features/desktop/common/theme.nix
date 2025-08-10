{
  inputs,
  pkgs,
  ...
}:
{
  stylix = {
    base16Scheme = "${inputs.tinted-theming}/base16/tokyo-night-dark.yaml";

    opacity = {
      popups = 0.9;
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 32;
    };

    fonts = {
      emoji = {
        package = pkgs.openmoji-color;
        name = "OpenMoji Color";
      };

      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      sizes = {
        applications = 14;
        desktop = 12;
        popups = 14;
        terminal = 18;
      };
    };

    targets = {
      qt.platform = "qtct";
    };
  };
}

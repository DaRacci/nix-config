{ config, pkgs, inputs, ... }:

let
  inherit (inputs.nix-colours.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
in rec {
  gtk = {
    enable = true;

    font = {
      name = config.fontProfiles.regular.family;
      size = 12;
    };

    theme = {
      name = "Adwaita-dark";
      package = null;
    };

    iconTheme = {
      name = "Adwaita";
      package = pkgs.gnome.adwaita-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Ice";
      size = 32;
      package = pkgs.bibata-cursors;
    };
  };

  services.xsettingsd = {
    enable = true;
    settings = {
      "Net/ThemeName" = "${gtk.theme.name}";
      "Net/IconThemeName" = "${gtk.iconTheme.name}";
    };
  };
}
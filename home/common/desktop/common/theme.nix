{ config, pkgs, ... }: rec {
  gtk = {
    enable = true;

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

  qt = {
    enable = true;
    platformTheme = "gtk3";
    style.name = "adwaita-qt6";
  };

  fontProfiles = {
    enable = true;

    monospace = {
      family = "JetBrainsMono Nerd Font";
      package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      size = 18;
    };

    regular = {
      family = "Fira Sans";
      package = pkgs.fira;
      size = 12;
    };

    emoji = {
      family = "OpenMoji Color";
      package = pkgs.openmoji-color;
    };
  };
}
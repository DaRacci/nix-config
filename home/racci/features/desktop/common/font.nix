{ pkgs, ... }: {
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

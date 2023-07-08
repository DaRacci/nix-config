{ pkgs, ...}: {
  qt = {
    enable = true;
    platformTheme = "gtk";

    style = {
      package = pkgs.adwaita-qt;
      name = "adwaita-dark";
    };
  };
}
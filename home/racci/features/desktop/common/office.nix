{ pkgs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
    newsflash # RSS
    wike # Wiki
    papers # PDF viewer
    gnome-calendar
    gnome-clocks
    gnome-calculator
    gnome-contacts

    take-control-viewer
  ];

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.gnome.Papers.desktop";
  };

  user.persistence.directories = [
    ".config/news-flash"
    ".config/evolution"
    ".local/share/evolution"
    ".local/share/news-flash"
  ];
}

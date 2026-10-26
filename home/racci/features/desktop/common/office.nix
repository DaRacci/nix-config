{ pkgs, ... }:
let
  inherit (pkgs)
    gnome-calculator
    gnome-calendar
    gnome-clocks
    gnome-contacts
    libreoffice
    newsflash
    papers
    take-control-viewer
    wike
    ;
in
{
  home.packages = [
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

  user.persistence = {
    directories = [
      ".config/libreoffice/4/user/config"
      ".config/news-flash"
      ".config/evolution"
      ".local/share/evolution"
      ".local/share/news-flash"
    ];
    files = [
      ".config/libreoffice/4/user/registrymodifications.xcu"
    ];
  };
}

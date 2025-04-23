{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnome-calendar
    raider
    # errands # To-do
    newsflash # RSS
    wike # Wiki
    papers # PDF viewer
    decoder # QR codes
    dialect # Translation
    planify
    gnome-clocks
    gnome-calculator
    gnome-graphs
    gnome-contacts
  ];

  dconf.settings = {
    "io/github/mrvladus/List" = {
      sync-provider = 1;
      sync-url = "https://nextcloud.racci.dev/remote.php/dav/";
      sync-user = "Racci";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.gnome.Papers.desktop";
  };

  user.persistence.directories = [
    ".config/news-flash"
    ".config/evolution"
    ".local/share/errands"
    ".local/share/evolution"
    ".local/share/news-flash"
  ];
}

{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnome-calendar
    errands # To-do
    newsflash # RSS
    wike # Wiki
    papers # PDF viewer
    decoder # QR codes
    dialect # Translation
    gnome-graphs # Graphing
    gnome-contacts # Contacts
  ];

  dconf.settings = {
    "io/github/mrvladus/List" = {
      sync-provider = 1;
      sync-url = "https://nextcloud.racci.dev/remote.php/dav/";
      sync-user = "Racci";
    };

    "app/drey/Dialect" = {
      "live-translation" = false;
      "translators" = {
        "active" = "google";
      };
    };
  };

  user.persistence.directories = [
    ".config/news-flash"
    ".config/evolution"
    ".local/share/errands"
    ".local/share/evolution"
    ".local/share/news-flash"
  ];
}

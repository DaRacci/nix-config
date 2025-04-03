{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nautilus
    nautilus-python
    nautilus-open-any-terminal
    ffmpegthumbnailer

    baobab # Disk usage analyzer
    gnome-disk-utility # Disk utility
    file-roller # Archive manager
    impression # Bootable USB creator
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "nautilus.desktop;org.gnome.Nautilus.desktop" ];
  };

  dconf.settings = {
    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      "terminal" = "alacritty";
    };

    "org/gtk/gtk4/settings/file-chooser" = {
      sort-directories-first = true;
      show-hidden = true;
      location-mode = "path-bar";
    };

    "org/gtk/settings/file-chooser" = {
      show-hidden = true;
      sort-directories-first = true;
      location-mode = "path-bar";
    };
  };

  home.sessionVariables = {
    NAUTILUS_4_EXTENSION_DIR = "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
  };

  user.persistence.files = [ "config/gtk-3.0/bookmarks" ];
}

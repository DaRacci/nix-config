{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    nautilus
    nautilus-python
    nautilus-open-any-terminal

    # Thumbnailers
    ffmpegthumbnailer
    nufraw-thumbnailer
    # stl-thumb

    collision
    baobab # Disk usage analyzer
    gnome-disk-utility
    file-roller # Archive manager
    impression # Bootable USB creator

    # Backup tools
    pika-backup
    deja-dup
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
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

  # Persist the bookmarks if the user doesn't declaratively set them
  user.persistence.files = lib.optionals (!(config.xdg.configFile ? "gtk-3.0/bookmarks")) [
    ".config/gtk-3.0/bookmarks"
  ];
}

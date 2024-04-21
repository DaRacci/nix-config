{ osConfig, pkgs, ... }: {
  home.packages = with pkgs; [
    gnome.nautilus
    gnome.sushi
    baobab
    unstable.morgen
    unstable.karlender
    loupe
    gnome.totem
    gnome.file-roller
    gnome.gnome-disk-utility
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "nautilus.desktop;org.gnome.Nautilus.desktop" ];
  };

  home.sessionVariables = {
    NAUTILUS_4_EXTENSION_DIR = "${osConfig.system.path}/lib/nautilus/extensions-4";
  };
}

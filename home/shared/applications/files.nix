{ pkgs, ... }:
let
  nautEnv = pkgs.buildEnv {
    name = "nautilus-env";

    paths = with pkgs; [
      nautilus
      nautilus-python
      nautilus-open-any-terminal
    ];
  };
in
{
  home.packages = with pkgs; [
    nautEnv
    baobab # Disk usage analyzer
    gnome-disk-utility # Disk utility
    file-roller # Archive manager
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "nautilus.desktop;org.gnome.Nautilus.desktop" ];
  };

  dconf.settings = {
    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      "terminal" = "alacritty";
    };
  };

  home.sessionVariables = {
    NAUTILUS_4_EXTENSION_DIR = "${nautEnv}/lib/nautilus/extensions-4";
  };
}

{ pkgs, ... }:
{
  imports = [
    ./keyboard.nix
    ./kvm.nix
    ./misc.nix
    ./mobile.nix
    ./office.nix
    ./secrets.nix
    ./sync.nix
    ./zed.nix
  ];

  xdg = {
    mimeApps.enable = true;
    configFile."gtk-3.0/bookmarks".text = ''
      file:///home/racci/Downloads Downloads
      file:///home/racci/Documents Documents
      file:///home/racci/Projects Projects
      file:///home/racci/Pictures Pictures
      file:///home/racci/Videos Videos
    '';
  };

  home.packages = with pkgs; [
    health
    fragments
    transmission_4-gtk
    kooha
  ];
}

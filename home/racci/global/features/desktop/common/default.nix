{ pkgs, ... }: {
  imports = [
    ./denaro.nix
    ./discord.nix
    ./firefox.nix
    ./flowtime.nix
    ./spotify.nix
    ./obsidian.nix
    ./podman.nix
    ./rnote.nix
    ./secrets.nix
    ./wine.nix
    
    # Theme related
    ./font.nix
    ./gtk.nix
    ./qt.nix
  ];

  # tf is this
  xdg.mimeApps.enable = true;

  home.packages = with pkgs; [ eltrafico ];
}
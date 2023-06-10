{
  imports = [
    ./discord.nix
    ./firefox.nix
    ./spotify.nix
    ./obsidian.nix
    ./pass.nix
    ./wine.nix
    
    # Theme related
    ./font.nix
    ./gtk.nix
    ./qt.nix
  ];

  # tf is this
  xdg.mimeApps.enable = true;
}
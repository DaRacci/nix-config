{
  imports = [
    ./discord.nix
    ./firefox.nix
    ./spotify.nix
    ./pass.nix
    
    # Theme related
    ./font.nix
    ./gtk.nix
    ./qt.nix
  ];

  # tf is this
  xdg.mimeApps.enable = true;
}
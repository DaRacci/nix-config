{
  imports = [
    # ./1password.nix
    ./discord.nix
    ./firefox.nix
    ./spotify.nix
    
    # Theme related
    ./font.nix
    ./gtk.nix
    ./qt.nix
  ];

  # tf is this
  xdg.mimeApps.enable = true;
}
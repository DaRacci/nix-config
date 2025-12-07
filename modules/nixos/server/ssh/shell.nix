{ pkgs ? import <nixpkgs> {} }:
let
  fishInit = pkgs.writeText "fish-init.fish" ''
    zoxide init fish | source
    starship init fish | source
    carapace _carapace fish | source
    
    alias grep='rg'
    alias cat='bat'
    alias ps='procs'
    alias find='fd'
  '';
in
pkgs.mkShellNoCC {
  name = "ssh-shell";

  packages = with pkgs; [
    # Prompts and shells
    starship
    zoxide
    carapace
    fish

    # Useful modern CLI utilities
    ripgrep
    fd
    bat
    procs
    doggo

    # Core tooling typically expected
    coreutils
    findutils
    gnugrep
    gawk
    less
    openssh
    git

    # System Info
    inxi
    pciutils
    hyfetch
  ];

  # Configure the interactive session. This runs when the shell starts.
  shellHook = ''
    fish -C 'source ${fishInit}'
    exit
  '';
}

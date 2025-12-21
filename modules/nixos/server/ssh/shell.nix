{
  pkgs ? import <nixpkgs> { },
}:
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

    # CLI utilities
    ripgrep
    fd
    bat
    procs
    doggo
    helix
    btop

    # Core tooling typically expected
    uutils-coreutils-noprefix
    uutils-findutils-noprefix
    gawk
    less
    openssh
    git
    curl
    lsof

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

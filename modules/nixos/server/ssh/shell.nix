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
    gping
    dust
    duf
    ncdu

    # Core tooling typically expected
    uutils-coreutils-noprefix
    uutils-findutils
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

  # Configure the interactive session. Runs when nix-shell evaluates this.
  # exec replaces the shellHook subprocess with fish, keeping it as the
  # interactive session until the user exits.
  shellHook = ''
    exec fish -C 'source ${fishInit}'
  '';
}

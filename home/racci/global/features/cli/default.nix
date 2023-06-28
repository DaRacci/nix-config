{ pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat.nix
    ./bottom.nix
    ./broot.nix
    ./direnv.nix
    ./git.nix
    # ./gpg.nix
    ./keyring.nix
    ./micro.nix
    ./nushell.nix
    ./ssh.nix
    ./starship.nix
    ./xplr.nix
    ./zoxide.nix
  ];

  home.packages = with pkgs; [
    btop
    glances
    nvtop
    ctop

    fd
    du-dust
    duf
    procs

    nil
    nixfmt
  ];
}
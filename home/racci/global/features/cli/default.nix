{ pkgs, ... }: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./git.nix
    # ./gpg.nix
    ./micro.nix
    ./ssh.nix
    ./xplr.nix
  ];

  home.packages = with pkgs; [
    btop
    glances
    nvtop
    ctop

    ripgrep
    fd
    du-dust
    duf
    procs

    nil
    nixfmt
  ];
}
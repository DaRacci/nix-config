{ pkgs, ... }: {
  imports = [
    ./bat.nix
    ./direnv.nix
    ./git.nix
    # ./gpg.nix
    ./keyring.nix
    ./micro.nix
    ./nushell.nix
    ./ssh.nix
    ./xplr.nix
    ./zoxide.nix
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
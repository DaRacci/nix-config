{ pkgs, ... }: {
  imports = [
    ./ai.nix
    ./atuin.nix
    ./azure.nix
    ./bat.nix
    ./bottom.nix
    ./broot.nix
    ./carapace.nix
    ./direnv.nix
    # ./gpg.nix
    ./keyring.nix
    ./micro.nix
    ./nushell.nix
    ./ripgrep.nix
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
    doggo

    nil
    nixfmt
  ];
}

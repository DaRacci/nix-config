{ pkgs, ... }: {
  imports = [
    ./atuin.nix
    ./bat.nix
    ./bottom.nix
    ./broot.nix
    ./carapace.nix
    ./direnv.nix
    ./info.nix
    ./keyring.nix
    ./nix.nix
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

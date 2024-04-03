{ pkgs, lib, ... }: {
  imports = [
    ./atuin.nix
    ./bat.nix
    ./carapace.nix
    ./direnv.nix
    ./files.nix
    ./fish.nix
    ./info.nix
    ./micro.nix
    ./monitors.nix
    ./nix.nix
    ./nushell.nix
    ./ripgrep.nix
    ./ssh.nix
    ./starship.nix
    ./zoxide.nix
  ];

  home.packages = with pkgs; [
    fd
    du-dust
    duf
    procs
    doggo
  ];
}

{ pkgs, ... }:
{
  imports = [
    ./atuin.nix
    ./bat.nix
    ./carapace.nix
    ./direnv.nix
    ./files.nix
    ./fish.nix
    ./info.nix
    ./micro.nix
    ./nix.nix
    ./nushell.nix
    ./ripgrep.nix
    ./starship.nix
    ./sys.nix
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

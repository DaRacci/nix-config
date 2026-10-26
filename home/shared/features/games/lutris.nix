{ pkgs, ... }:
let
  inherit (pkgs) lutris;
in
{
  home.packages = [ lutris ];

  user.persistence.directories = [
    ".config/lutris"
    ".local/share/lutris/games" # TODO :: Are the other folders required too?
  ];
}

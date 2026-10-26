{ pkgs, ... }:
let
  inherit (pkgs) teams-for-linux;
in
{
  home.packages = [
    teams-for-linux
  ];

  user.persistence.directories = [
    ".config/teams-for-linux"
  ];
}

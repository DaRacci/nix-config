{ pkgs, ... }:
let
  inherit (pkgs) teams-for-linux;
in
{
  home.packages = [
    teams-for-linux
  ];

  user.files.persistence.directories = [
    ".config/teams-for-linux"
  ];
}

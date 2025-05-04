{ pkgs, ... }:
{
  home.packages = with pkgs; [
    teams-for-linux
  ];

  user.persistence.directories = [
    ".config/teams-for-linux"
  ];
}

{ pkgs, ... }:
{
  home.packages = with pkgs; [ lutris ];

  user.persistence.directories = [
    ".config/lutris"
    ".local/share/lutris/games" # TODO :: Are the other folders required too?
  ];
}

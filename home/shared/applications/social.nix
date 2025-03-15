{ pkgs, ... }:
{
  home.packages = with pkgs; [ discord ];

  user.persistence.directories = [
    ".config/discord"
    ".config/Vencord"
  ];
}

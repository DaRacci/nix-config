{ pkgs, ... }:
{
  home.packages = with pkgs; [
    discord
    tuba
    polari
  ];

  user.persistence.directories = [
    ".config/discord"
    ".config/Vencord"
    ".local/share/polari"
  ];
}

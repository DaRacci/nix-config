{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nextcloud-talk-desktop
    discord
    tuba
    polari
  ];

  user.persistence.directories = [
    ".config/Nextcloud Talk"
    ".config/discord"
    ".local/share/polari"
  ];
}

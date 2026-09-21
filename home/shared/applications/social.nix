{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nextcloud-talk-desktop
    discord
    tuba
    polari
  ];

  user.persistence.directories = [
    ".config/Vencord/settings"
    ".config/Nextcloud Talk"
    ".config/discord"
    ".local/share/polari"
  ];
}

{ pkgs, ... }:
let
  inherit (pkgs)
    discord
    nextcloud-talk-desktop
    polari
    tuba
    ;
in
{
  home.packages = [
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

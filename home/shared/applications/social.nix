{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (discord.override {
      # OpenASAR completely breaks Discord
      # withOpenASAR = true;
      withVencord = true;
      nss = nss_latest;
    })
  ];

  user.persistence.directories = [
    ".config/discord"
    ".config/Vencord"
  ];
}

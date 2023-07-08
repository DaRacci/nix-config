{ pkgs, ...}: {
  # services.spotifyd = {
  #   enable = false;
  #   package = (pkgs.spotifyd.override { withKeyring = true; });
  # };

  home.packages = with pkgs; [ spot spotify spicetify-cli ];

  home.persistence."/persist/home/racci".directories = [
    ".config/spotify"
    ".cache/spot"
  ];
}
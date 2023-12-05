{ pkgs, ... }: {
  # services.spotifyd = {
  #   enable = false;
  #   package = (pkgs.spotifyd.override { withKeyring = true; });
  # };

  home.packages = with pkgs; [ spot spotify spicetify-cli ];

  user.persistence.directories = [
    ".config/spotify"
    ".cache/spot"
  ];
}

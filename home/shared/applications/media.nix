{ pkgs, ... }: {
  home.packages = with pkgs; [ unstable.spotify ];

  user.persistence.directories = [
    ".config/spotify"
  ];
}

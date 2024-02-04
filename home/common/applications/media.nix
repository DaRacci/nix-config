{ pkgs, ... }: {
  home.packages = with pkgs; [ spotify ];

  user.persistence.directories = [
    # ".local/share/spotube"
    ".config/spotify"
  ];
}

{ pkgs, ... }: {
  home.packages = with pkgs; [ spotify ];

  user.persistence.directories = [
    ".config/spotify"
  ];
}

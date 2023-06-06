{ pkgs, ... }: {
  home.packages = with pkgs; [ _1password ];

  # TODO :: link to gui if possible, setup persistent storage
}
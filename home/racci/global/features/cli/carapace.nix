{ pkgs, config, ... }: {
  home.packages = with pkgs; [ carapace ];
}
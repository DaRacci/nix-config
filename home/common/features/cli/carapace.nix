{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ carapace ];
}

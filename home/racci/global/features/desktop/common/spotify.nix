{ pkgs, ...}: {
  # services.spotifyd = {
  #   enable = false;
  #   package = (pkgs.spotifyd.override { withKeyring = true; });
  # };

  home.packages = with pkgs; [ spot ];
}
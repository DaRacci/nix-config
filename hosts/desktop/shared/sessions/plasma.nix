{
  pkgs,
  ...
}:
let
  inherit (pkgs.kdePackages)
    ark
    baloo-widgets
    dolphin-plugins
    elisa
    ffmpegthumbs
    gwenview
    kate
    khelpcenter
    konsole
    okular
    plasma-browser-integration
    ;
in
{
  imports = [
    ./default.nix
  ];

  services = {
    desktopManager.plasma6.enable = true;
    orca.enable = false;
  };

  environment.plasma6.excludePackages = [
    plasma-browser-integration
    konsole
    ark
    elisa
    gwenview
    okular
    kate
    khelpcenter
    baloo-widgets
    dolphin-plugins
    ffmpegthumbs
  ];
}

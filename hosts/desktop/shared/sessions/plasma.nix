{
  pkgs,
  ...
}:
{
  services = {
    desktopManager.plasma6.enable = true;
    orca.enable = false;
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
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

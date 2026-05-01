{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault;
in
{

  imports = [
    ./storage
    ./backlight.nix
    ./biometrics.nix
    ./bluetooth.nix
    ./cooling.nix
    ./display.nix
    ./openrgb.nix
    ./graphics.nix
  ];

  options = { };

  config = {
    hardware.enableRedistributableFirmware = mkDefault (!config.host.device.isVirtual);
  };
}

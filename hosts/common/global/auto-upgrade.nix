{ config, flake, ... }:

let
  inherit (config.networking) hostName;
  isClean = flake ? rev;
in
{
  system.autoUpgrade = {
    enable = isClean;
    dates = "hourly";
    flags = [ "--refresh" ];
    flake = "github:DaRacci/nix-config#${hostName}";

    allowReboot = false;
    rebootWindow = { lower = "02:00"; upper = "05:00"; };
  };
}

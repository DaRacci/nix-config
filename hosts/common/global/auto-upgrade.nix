{ config, inputs, ... }:

let
  inherit (config.networking) hostName;
  isClean = inputs.self ? rev;
in {
  system.autoUpgrade = {
    enable = isClean;
    dates = "hourly";
    flags = [ "--refresh" ];
    flake = "github:DaRacci/nix-config#${hostName}";
    
    allowReboot = true;
    rebootWindow = { lower = "02:00"; upper = "05:00"; };
  };
}
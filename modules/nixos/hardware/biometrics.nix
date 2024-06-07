{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.hardware.fingerprintReader;
in
{
  options.hardware.fingerprintReader = {
    enable = mkEnableOption "fingerprint reader support";
  };

  config = mkIf cfg.enable {
    services.fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = pkgs.libfprint-2-tod1-goodix;
      };
    };
  };
}

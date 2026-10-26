{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.purpose.modelling;
in
{
  imports = [ ./blender.nix ];

  options.purpose.modelling = {
    enable = mkEnableOption "moddeling";
  };

  config = mkIf cfg.enable { };
}

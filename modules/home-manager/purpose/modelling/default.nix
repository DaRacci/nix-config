{ config, lib, ... }:
with lib;
let
  cfg = config.purpose.modelling;
in
{
  imports = [ ./blender.nix ];

  options.purpose.modelling = {
    enable = mkEnableOption "moddeling";
  };

  config = mkIf cfg.enable { };
}

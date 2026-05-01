{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    ;
  cfg = config.core.networking;
in
{
  imports = [
    ./tailscale.nix
  ];

  options.core.networking = {
    enable = (mkEnableOption "opinionated networking defaults") // {
      default = config.core.enable;
      defaultText = literalExpression "config.core.enable";
    };
  };

  config = mkIf cfg.enable {
    networking = {
      enableIPv6 = true;

      firewall = {
        logRefusedConnections = false;
        logRefusedPackets = false;
        logReversePathDrops = false;
      };
    };
  };
}

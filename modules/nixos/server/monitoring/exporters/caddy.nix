_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;
in
{
  config = mkIf (cfg.enable && cfg.exporters.caddy.enable) {
    services.caddy.globalConfig = lib.mkAfter ''
      servers {
        metrics {
          listen 0.0.0.0:2019
        }
      }
    '';

    server.network.openPortsForSubnet.tcp = [ 2019 ];
  };
}

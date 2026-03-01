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
      metrics {
        per_host
      }
    '';

    server.network.openPortsForSubnet.tcp = [ 2019 ];
  };
}

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
    services.caddy = {
      globalConfig = lib.mkAfter ''
        metrics {
          per_host
        }
      '';

      # TODO:Restrict to only accessable from the prometheus server, mTLS?
      virtualHosts.":3019".extraConfig = ''
        metrics
      '';

    };

    server.network.openPortsForSubnet.tcp = [ 3019 ];
  };
}

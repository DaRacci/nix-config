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
  config = mkIf (cfg.enable && cfg.exporters.fail2ban.enable) {
    services.prometheus.exporters.fail2ban = {
      enable = true;
      port = 9191;
      listenAddress = "::";
    };

    server.network.openPortsForSources.${config.server.monitoringPrimaryHost}.tcp = [
      config.services.prometheus.exporters.fail2ban.port
    ];
  };
}

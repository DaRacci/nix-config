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
      listenAddress = "0.0.0.0";
    };

    server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.fail2ban.port ];
  };
}

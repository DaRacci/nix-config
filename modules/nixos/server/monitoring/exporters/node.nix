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
  config = mkIf (cfg.enable && cfg.exporters.node.enable) {
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      listenAddress = "0.0.0.0";
      enabledCollectors = [
        "cpu"
        "diskstats"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "netstat"
        "stat"
        "time"
        "vmstat"
        "systemd"
        "logind"
        "processes"
      ];
    };

    server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.node.port ];
  };
}

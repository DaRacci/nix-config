_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkMerge;

  cfg = config.server.monitoring;
in
{
  config = mkMerge [
    (mkIf (cfg.enable && cfg.exporters.caddy.enable) {
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
    })

    (mkIf (cfg.enable && cfg.exporters.caddy.enable && cfg.logs.enable) {
      server.monitoring.logs.extraConfiguration = ''
        loki.source.file "caddy_access" {
          file_match {
            enabled = true
          }

          targets = [
            {
              __path__ = "/var/log/caddy/*.log"
              __path_exclude__ = "/var/log/caddy/*.gz"
              job = "caddy_access"
            }
          ]

          forward_to = [loki.process.caddy.receiver]
        }

        loki.process "caddy" {
          stage.json {
            expressions = {
              level = "level"
              ts = "ts"
              msg = "msg"
              logger = "logger"
              bytes_read = "bytes_read"
              duration = "duration"
              size = "size"
              status = "status"
              ip = "request.remote_addr"

              request = "request"
              resp_headers = "resp_headers"
            }
          }

          stage.geoip {
            dsb = "ip"
          }

          stage.labels {
            values = {
              detected_level = "detected_level"
              logger = "logger"
              status = "status"
            }
          }

          stage.timestamp {
            source = "ts"
            format = "Unix"
          }
        }
      '';
    })
  ];
}

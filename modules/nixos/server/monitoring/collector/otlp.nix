{
  getIOPrimaryHostAttr,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;
  domain = getIOPrimaryHostAttr "server.proxy.domain";
  listenAddress = "0.0.0.0";

  tempoEnabled = cfg.collector.tempo.enable or false;
in
{
  config = mkIf (cfg.enable && cfg.collector.enable && cfg.collector.otlp.enable) {
    server = {
      proxy.virtualHosts.${cfg.collector.otlp.subdomain} = {
        public = true;
        ports = [ cfg.collector.otlp.port ];
        extraConfig = ''
          reverse_proxy http://${listenAddress}:${toString cfg.collector.otlp.port}
        '';
      };

      dashboard.items.${cfg.collector.otlp.subdomain} = {
        title = "OTLP";
        url = "https://${cfg.collector.otlp.subdomain}.${domain}";
        icon = "mdi-transit-connection-variant";
      };

      monitoring.logs.extraConfiguration = ''
        otelcol.auth.bearer "otlp" {
          token = sys.env("OTLP_BEARER_TOKEN")
        }

        prometheus.remote_write "otlp" {
          endpoint {
            url = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/write"
          }
        }

        otelcol.exporter.prometheus "otlp" {
          forward_to = [prometheus.remote_write.otlp.receiver]
        }

        otelcol.exporter.loki "otlp" {
          forward_to = [loki.write.default.receiver]
        }

        ${if tempoEnabled then ''
        otelcol.exporter.otlphttp "tempo" {
          client {
            url = "http://127.0.0.1:${toString cfg.collector.tempo.otlpPort}"
          }
        }
        '' else ""}

        otelcol.receiver.otlp "default" {
          http {
            endpoint = "0.0.0.0:${toString cfg.collector.otlp.port}"
            auth     = otelcol.auth.bearer.otlp.handler
          }

          output {
            metrics = [otelcol.exporter.prometheus.otlp.input]
            logs    = [otelcol.exporter.loki.otlp.input]
            traces  = [${if tempoEnabled then "otelcol.exporter.otlphttp.tempo.input" else ""}]
          }
        }
      '';
    };
  };
}

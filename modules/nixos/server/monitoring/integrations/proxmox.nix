{
  isThisMonitoringPrimaryHost,
  ...
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;
in
{
  config =
    mkIf
      (cfg.enable && cfg.collector.enable && cfg.collector.proxmox.enable && isThisMonitoringPrimaryHost)
      {
        services.prometheus.exporters.pve = {
          enable = true;
          port = 9221;
          listenAddress = "0.0.0.0";

          configFile = config.sops.templates."pve-exporter.yml".path;
        };

        services.prometheus.scrapeConfigs = [
          {
            job_name = "proxmox";
            static_configs = [
              { targets = [ "localhost:9221" ]; }
            ];
          }
        ];

        sops.secrets."proxmox/api_url" = { };
        sops.secrets."proxmox/token_id" = { };
        sops.secrets."proxmox/token_secret" = { };

        sops.templates."pve-exporter.yml" = {
          content = builtins.toJSON {
            default = {
              user = config.sops.placeholder."proxmox/token_id";
              token_name = config.sops.placeholder."proxmox/token_id";
              token_value = config.sops.placeholder."proxmox/token_secret";
              verify_ssl = false;
            };
          };
        };
      };
}

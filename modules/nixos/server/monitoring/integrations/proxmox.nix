{
  isThisMonitoringPrimaryHost,
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
in
{
  config =
    mkIf
      (cfg.enable && cfg.collector.enable && cfg.collector.proxmox.enable && isThisMonitoringPrimaryHost)
      {
        sops = {
          secrets = {
            "PROXMOX/API_URL" = { };
            "PROXMOX/USER" = { };
            "PROXMOX/TOKEN_ID" = { };
            "PROXMOX/TOKEN_SECRET" = { };
          };

          templates."pve-exporter.yml" = {
            content = builtins.toJSON {
              default = {
                user = config.sops.placeholder."PROXMOX/USER";
                token_name = config.sops.placeholder."PROXMOX/TOKEN_ID";
                token_value = config.sops.placeholder."PROXMOX/TOKEN_SECRET";
                verify_ssl = false;
              };
            };
          };
        };

        services.prometheus.exporters.pve = {
          enable = true;
          port = 9221;
          listenAddress = "127.0.0.1";

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
      };
}

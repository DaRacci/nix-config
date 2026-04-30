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
  config = mkIf (cfg.enable && cfg.collector.enable && cfg.collector.proxmox.enable) {
    sops = {
      secrets = {
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
        job_name = "pve";
        static_configs = [
          { targets = [ "pve.racci.dev:443" ]; }
        ];
        metrics_path = "/pve";
        params = {
          target = [ "pve.racci.dev:443" ];
          module = [ "default" ];
          cluster = [ "1" ];
          node = [ "1" ];
        };
        relabel_configs = [
          {
            source_labels = [ "__address__" ];
            target_label = "instance";
          }
          {
            source_labels = [ "__param_target" ];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:9221";
          }
        ];
      }
    ];
  };
}

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
  inherit (lib) mkIf mkMerge;

  cfg = config.server.monitoring;
  grafanaCfg = cfg.collector.grafana;
  domain = getIOPrimaryHostAttr "server.proxy.domain";
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) (mkMerge [
    {
      services.grafana = {
        enable = true;

        settings = {
          server = {
            http_addr = "0.0.0.0";
            http_port = 3000;
            domain = "grafana.${domain}";
            root_url = "https://grafana.${domain}";
          };

          analytics.reporting_enabled = false;

          security.secret_key = "$__file{${config.sops.secrets."MONITORING/GRAFANA/SECRET_KEY".path}}";
        };

        provision = {
          enable = true;
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              url = "http://localhost:9090";
              isDefault = true;
              access = "proxy";
            }
            {
              name = "Loki";
              type = "loki";
              url = "http://localhost:3100";
              access = "proxy";
            }
          ];
        };
      };

      networking.firewall.allowedTCPPorts = [ 3000 ];

      sops.secrets."MONITORING/GRAFANA/SECRET_KEY" = {
        owner = "grafana";
        group = "grafana";
      };
    }

    (mkIf grafanaCfg.kanidm.enable {
      services.grafana.settings = {
        "auth.generic_oauth" = {
          enabled = true;
          name = "Kanidm";
          icon = "signin";
          allow_sign_up = true;
          auto_login = false;

          client_id = "grafana";
          client_secret = "$__file{${config.sops.secrets."GRAFANA_OAUTH_SECRET".path}}";

          scopes = "openid profile email groups";
          auth_url = "https://auth.${domain}/ui/oauth2";
          token_url = "https://auth.${domain}/oauth2/token";
          api_url = "https://auth.${domain}/oauth2/openid/grafana/userinfo";
          use_pkce = true;

          login_attribute_path = "preferred_username";
          name_attribute_path = "name";
          role_attribute_path = "contains(groups[*], 'grafana_admins') && 'Admin' || contains(groups[*], 'grafana_editors') && 'Editor' || 'Viewer'";
          role_attribute_strict = false;
          allow_assign_grafana_admin = true;
        };

        auth = {
          disable_login_form = false;
          signout_redirect_url = "https://auth.${domain}/ui/logout";
        };
      };

      sops.secrets."GRAFANA_OAUTH_SECRET" = {
        owner = "grafana";
        group = "grafana";
      };
    })
  ]);
}

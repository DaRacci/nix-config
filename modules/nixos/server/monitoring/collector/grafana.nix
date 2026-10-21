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
  captureCfg = cfg.logs.capture;
  relayCfg = captureCfg.relay;
  domain = getIOPrimaryHostAttr "server.proxy.domain";

  sanitiseHost = host: builtins.replaceStrings [ "." "_" ] [ "-" "-" ] host;

  relayContactPoints =
    relayCfg.targets
    |> map (
      host:
      let
        hostId = sanitiseHost host;
      in
      [
        {
          orgId = 1;
          name = "alloy-capture-${host}-enable";
          receivers = [
            {
              uid = "alloy-capture-${hostId}-enable";
              type = "webhook";
              disableResolveMessage = true;
              settings = {
                url = "http://${relayCfg.listenAddress}:${toString relayCfg.port}/capture/${host}/enable?ttl=${toString relayCfg.defaultTTLSeconds}";
                httpMethod = "POST";
              };
            }
          ];
        }
        {
          orgId = 1;
          name = "alloy-capture-${host}-disable";
          receivers = [
            {
              uid = "alloy-capture-${hostId}-disable";
              type = "webhook";
              disableResolveMessage = true;
              settings = {
                url = "http://${relayCfg.listenAddress}:${toString relayCfg.port}/capture/${host}/disable";
                httpMethod = "POST";
              };
            }
          ];
        }
      ]
    )
    |> builtins.concatLists;
in
{
  config = mkIf (cfg.enable && cfg.collector.enable) (mkMerge [
    {
      server.proxy.virtualHosts.grafana =
        let
          inherit (config.services.grafana.settings.server) http_port http_addr;
        in
        {
          public = true;
          ports = [ http_port ];
          extraConfig = ''
            reverse_proxy http://${http_addr}:${toString http_port}
          '';
        };

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
              uid = "prometheus";
              url = "http://localhost:9090";
              isDefault = true;
              access = "proxy";
            }
            {
              name = "Loki";
              type = "loki";
              uid = "loki";
              url = "http://localhost:3100";
              access = "proxy";
            }
          ];
        };
      };

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
          client_secret = "$__file{${config.sops.secrets."MONITORING/GRAFANA/OAUTH_SECRET".path}}";

          scopes = "openid,profile,email,groups";
          auth_url = "https://auth.${domain}/ui/oauth2";
          token_url = "https://auth.${domain}/oauth2/token";
          api_url = "https://auth.${domain}/oauth2/openid/grafana/userinfo";
          use_pkce = true;
          use_refresh_token = true;

          login_attribute_path = "preferred_username";
          groups_attribute_path = "groups";
          role_attribute_path = "contains(grafana_role[*], 'admin') && 'GrafanaAdmin' || contains(grafana_role[*], 'editor') && 'Editor' || 'Viewer'";
          role_attribute_strict = true;
          allow_assign_grafana_admin = true;
        };

        auth = {
          disable_login_form = true;
        };
      };

      sops.secrets."MONITORING/GRAFANA/OAUTH_SECRET" = {
        owner = "grafana";
        group = "grafana";
      };
    })

    (mkIf (captureCfg.enable && relayCfg.enable) {
      services.grafana.provision.alerting.contactPoints.settings = {
        apiVersion = 1;
        contactPoints = relayContactPoints;
      };
    })
  ]);
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    toShellVars
    concatStringsSep
    mkEnableOption
    mkOption
    mkMerge
    mkIf
    types
    ;
  inherit (types)
    addCheck
    listOf
    nullOr
    int
    str
    ;

  cfg = config.services.ai-agent;

  dashboardReadinessAttempts = 150;
  dashboardReadinessIntervalSec = 2;
  dashboardReadinessBudgetSec = dashboardReadinessAttempts * dashboardReadinessIntervalSec;
  # Every attempt costs `docker exec` overhead on top of its sleep,
  # so a start timeout equal to the budget would fire before the loop could report the failure itself.
  dashboardStartTimeoutSec = dashboardReadinessBudgetSec + 30;
in
{
  options.services.ai-agent.dashboard = {
    enable = mkEnableOption "Hermes web dashboard";

    port = mkOption {
      type = int;
      default = 9119;
      description = "The port for the dashboard to listen on.";
    };

    publicURL = mkOption {
      type = nullOr (addCheck str (url: builtins.match "https?://.+" url != null));
      default = null;
      description = ''
        The public URL for the dashboard, used for generating links in notifications and similar. If not set, localhost URLs will be used.

        If set, must be a valid URL starting with http:// or https://.
      '';
    };

    oidc = {
      enable = mkEnableOption "OpenID Connect authentication for the dashboard";

      provider = mkOption {
        type = str;
        default = "self-hosted";
        description = "The OIDC plugin to use for dashboard authentication.";
      };

      issuer = mkOption {
        type = nullOr str;
        default = null;
        description = "The OIDC issuer URL for dashboard authentication.";
      };

      clientId = mkOption {
        type = nullOr str;
        default = null;
        description = "The OIDC client ID for dashboard authentication.";
      };

      scopes = mkOption {
        type = listOf str;
        default = [
          "openid"
          "profile"
          "email"
        ];
        description = "The OIDC scopes to request for dashboard authentication.";
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable && cfg.dashboard.enable) {
      services.ai-agent.settings.dashboard = {
        public_url = cfg.dashboard.publicURL;
      };

      systemd.services.hermes-dashboard = {
        description = "Hermes web dashboard";
        after = [
          "network.target"
          "docker.service"
          "hermes-agent.service"
        ];
        requires = [ "docker.service" ];
        bindsTo = [ "hermes-agent.service" ];
        wantedBy = [ "multi-user.target" ];

        # hermes-agent.service is Type=simple: `docker start -a` is considered "started" as soon as it is spawned,
        # so After=hermes-agent.service does NOT guarantee the container is up and accepting exec yet.
        # Without a readiness wait the `docker exec` in ExecStart races container (re)creation, fails instantly,
        # and the resulting burst of failed starts can trip systemd's default start rate limit (StartLimitBurst=5 within StartLimitIntervalSec=10s),
        # leaving the unit stuck in `failed` and refusing to start even after the container is healthy.
        # Disable the rate limit so Restart=always keeps retrying, and gate the real start on the container actually accepting an exec as the hermes user.
        startLimitIntervalSec = 0;

        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "simple";
          User = "hermes";
          Group = "hermes";
          EnvironmentFile = config.services.hermes-agent.environmentFiles;
          PrivateTmp = true;
          TimeoutStartSec = dashboardStartTimeoutSec;
          ExecStartPre = "${lib.getExe pkgs.bash} -c 'for ((i = 0; i < ${toString dashboardReadinessAttempts}; i++)); do docker exec -u hermes hermes-agent true 2>/tmp/hermes-dashboard-ready.err && exit 0; sleep ${toString dashboardReadinessIntervalSec}; done; echo \"hermes-agent container not ready after ~${toString dashboardReadinessBudgetSec}s; last docker exec error:\" >&2; cat /tmp/hermes-dashboard-ready.err >&2 || true; exit 1'";
          ExecStart = "${lib.getExe pkgs.bash} -c 'env > /tmp/hermes-dashboard.env; exec docker exec -u hermes --env-file /tmp/hermes-dashboard.env hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --no-open --port ${toString cfg.dashboard.port}'";
          Restart = "always";
          RestartSec = 5;
          SupplementaryGroups = [ "docker" ];
          ReadWritePaths = [ "/var/run/docker.sock" ];
        };
      };

      networking.firewall.allowedTCPPorts = [ cfg.dashboard.port ];
    })

    (mkIf (cfg.enable && cfg.dashboard.enable && cfg.dashboard.oidc.enable) {
      assertions = [
        {
          assertion = cfg.dashboard.oidc.issuer != null;
          message = "OIDC issuer must be specified when OIDC authentication is enabled.";
        }
        {
          assertion = cfg.dashboard.oidc.clientId != null;
          message = "OIDC client ID must be specified when OIDC authentication is enabled.";
        }
      ];

      sops.templates."HERMES_DASHBOARD_OIDC_ENV".content = toShellVars {
        HERMES_DASHBOARD_OIDC_ISSUER = cfg.dashboard.oidc.issuer;
        HERMES_DASHBOARD_OIDC_CLIENT_ID = cfg.dashboard.oidc.clientId;
        HERMES_DASHBOARD_OIDC_SCOPES = concatStringsSep " " cfg.dashboard.oidc.scopes;
      };

      services = {
        hermes-agent.environmentFiles = [ config.sops.templates."HERMES_DASHBOARD_OIDC_ENV".path ];
        ai-agent.settings.dashboard.oauth = {
          inherit (cfg.dashboard.oidc) provider;
          "${cfg.dashboard.oidc.provider}" = {
            inherit (cfg.dashboard.oidc) issuer scopes;
            client_id = cfg.dashboard.oidc.clientId;
          };
        };
      };
    })
  ];
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    types
    getExe
    optional
    toShellVars
    mkIf
    mkOption
    mkEnableOption
    ;
  inherit (types)
    package
    str
    port
    bool
    nullOr
    path
    attrsOf
    listOf
    int
    ;
  cfg = config.services.firecrawl;
in
{
  options.services.firecrawl = {
    enable = mkEnableOption "Firecrawl service";

    package = mkOption {
      type = package;
      default = pkgs.firecrawl;
      description = "Package providing Firecrawl.";
    };

    host = mkOption {
      type = str;
      default = "0.0.0.0";
      description = "Listen address for Firecrawl.";
    };

    port = mkOption {
      type = port;
      default = 3002;
      description = "Listen port for Firecrawl.";
    };

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Whether to open the service port in the firewall.";
    };

    apiKeyFile = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        Path to file containing API key for self-hosted Firecrawl auth.
        This is optional unless instance is configured to require auth.
      '';
    };

    environment = mkOption {
      type = attrsOf str;
      default = { };
      description = "Extra environment variables passed to Firecrawl.";
    };

    extraArgs = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra args passed to Firecrawl binary.";
    };

    numWorkersPerQueue = mkOption {
      type = int;
      default = 8;
      description = "Worker count per queue.";
    };

    useDbAuthentication = mkOption {
      type = bool;
      default = false;
      description = "Enable DB authentication.";
    };

    bullAuthKeyFile = mkOption {
      type = nullOr path;
      default = null;
      description = "Optional file for BULL_AUTH_KEY.";
    };

    redisUrl = mkOption {
      type = str;
      default = "redis://redis:6379";
      description = "Redis URL used by Firecrawl.";
    };

    redisRateLimitUrl = mkOption {
      type = str;
      default = "redis://redis:6379";
      description = "Redis rate limit URL used by Firecrawl.";
    };
  };

  config = mkIf cfg.enable {
    sops.templates.firecrawlEnvironment = {
      content = toShellVars (
        cfg.environment
        // {
          PORT = toString cfg.port;
          HOST = cfg.host;
          NUM_WORKERS_PER_QUEUE = toString cfg.numWorkersPerQueue;
          USE_DB_AUTHENTICATION = builtins.toJSON cfg.useDbAuthentication;
          REDIS_URL = cfg.redisUrl;
          REDIS_RATE_LIMIT_URL = cfg.redisRateLimitUrl;
          BULL_AUTH_KEY = null;
        }
      );

      restartUnits = [ "firecrawl.service" ];
    };

    systemd.services.firecrawl = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = "/var/lib/firecrawl";
      };

      serviceConfig = {
        EnvironmentFile = config.sops.templates.firecrawlEnvironment.path;
        WorkingDirectory = "/var/lib/firecrawl";
        StateDirectory = "firecrawl";
        RuntimeDirectory = "firecrawl";
        DynamicUser = true;

        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateUsers = true;
        RemoveIPC = true;
        CapabilityBoundingSet = [ ];
        AmbientCapabilities = [ ];
        LoadCredential =
          optional (cfg.apiKeyFile != null) "apiKey:${cfg.apiKeyFile}"
          ++ optional (cfg.bullAuthKeyFile != null) "bullAuthKey:${cfg.bullAuthKeyFile}";
      };

      script = ''
        exec ${getExe cfg.package}
      '';

    };

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
  };
}

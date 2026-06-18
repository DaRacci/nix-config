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
    optionalAttrs
    toShellVars
    mkIf
    mkOption
    mkEnableOption
    toUpper
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

  # Repo-standard DB module references
  postgres = config.server.database.postgres.firecrawl or null;
  redis = config.server.database.redis.firecrawl or null;
  redisRateLimit = config.server.database.redis.firecrawl-rate-limit or null;

  # Check if using repo-managed DBs (vs overrides or no config)
  usingRepoRedis = redis != null || redisRateLimit != null;
  usingRepoPostgres = postgres != null;

  # Redis password placeholder: prefer REDIS_PASSWORD over REDIS/PASSWORD
  redisPasswordPlaceholder =
    config.sops.placeholder."REDIS_PASSWORD" or (config.sops.placeholder."REDIS/PASSWORD" or "");

  # Resolve effective connection strings:
  #   explicit option override > repo DB module > safe localhost default
  hasRedisOverride = cfg.redisUrl != null;
  hasRedisRateLimitOverride = cfg.redisRateLimitUrl != null;
  hasDatabaseOverride = cfg.databaseUrl != null;

  effectiveRedisUrl =
    if hasRedisOverride then
      cfg.redisUrl
    else if redis != null then
      "redis://:${redisPasswordPlaceholder}@${redis.host}:${toString redis.port}/${toString redis.database_id}"
    else
      "redis://127.0.0.1:6379";

  effectiveRedisRateLimitUrl =
    if hasRedisRateLimitOverride then
      cfg.redisRateLimitUrl
    else if redisRateLimit != null then
      "redis://:${redisPasswordPlaceholder}@${redisRateLimit.host}:${toString redisRateLimit.port}/${toString redisRateLimit.database_id}"
    else
      "redis://127.0.0.1:6379";

  # Build DATABASE_URL and NUQ_DATABASE_URL from repo postgres module when available
  databaseVars =
    if postgres != null && !hasDatabaseOverride then
      let
        dbNameUpper = toUpper (builtins.replaceStrings [ "-" ] [ "_" ] postgres.database);
        dsn = "postgresql://${postgres.user}:${
          config.sops.placeholder."POSTGRES/${dbNameUpper}_PASSWORD"
        }@${postgres.host}:${toString postgres.port}/${postgres.database}";
      in
      {
        DATABASE_URL = dsn;
        NUQ_DATABASE_URL = dsn;
      }
    else if hasDatabaseOverride then
      {
        DATABASE_URL = cfg.databaseUrl;
        NUQ_DATABASE_URL = cfg.databaseUrl;
      }
    else
      { };
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
      default = "127.0.0.1";
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
        Path to file containing an API key loaded via LoadCredential.
        NOTE: Upstream Firecrawl does NOT use FIRECRAWL_API_KEY for server auth.
        This option is retained for compatibility; the value is NOT exported
        as any standard env var. Use bullAuthKeyFile for BULL_AUTH_KEY.
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
      description = ''
        Enable Supabase-backed DB authentication (USE_DB_AUTHENTICATION=true).
        Not simple API-key auth. Requires Supabase integration upstream.
      '';
    };

    bullAuthKeyFile = mkOption {
      type = nullOr path;
      default = null;
      description = "Optional file for BULL_AUTH_KEY.";
    };

    redisUrl = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Override Redis URL. When null (default), uses repo DB module
        (config.server.database.redis.firecrawl) or "redis://127.0.0.1:6379".
      '';
    };

    redisRateLimitUrl = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Override Redis rate limit URL. When null (default), uses repo DB module
        (config.server.database.redis.firecrawl-rate-limit) or "redis://127.0.0.1:6379".
      '';
    };

    databaseUrl = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Override Postgres DSN. Exported as both DATABASE_URL and NUQ_DATABASE_URL.
        When null (default), builds from repo DB module
        (config.server.database.postgres.firecrawl).
      '';
    };

    openrouter = {
      enable = mkEnableOption "OpenRouter integration for Firecrawl AI models";

      apiKeyFile = mkOption {
        type = nullOr path;
        default = null;
        description = ''
          Path to file containing OpenRouter API key.
          Loaded via LoadCredential and exported as OPENROUTER_API_KEY.
        '';
      };

      modelName = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Optional AI model override (MODEL_NAME). When null, Firecrawl
          uses its own default.
        '';
      };

      modelEmbeddingName = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          Optional embedding model override (MODEL_EMBEDDING_NAME).
          When null, Firecrawl uses its own default.
        '';
      };
    };

    playwright = {
      browsersPath = mkOption {
        type = nullOr path;
        default = pkgs.playwright-driver.browsers;
        defaultText = pkgs.lib.literalExpression "pkgs.playwright-driver.browsers";
        description = ''
          Path to Playwright browsers. Defaults to Nix-provided browsers
          (pkgs.playwright-driver.browsers). Set to null to disable the
          override and let Playwright manage its own browsers.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = optional usingRepoRedis {
      assertion = config.sops.secrets ? "REDIS_PASSWORD" || config.sops.secrets ? "REDIS/PASSWORD";
      message = ''
        Firecrawl uses repo-managed Redis (config.server.database.redis.firecrawl*)
        but neither sops.secrets.REDIS_PASSWORD nor sops.secrets."REDIS/PASSWORD" is defined.

        Define one of:
          sops.secrets.REDIS_PASSWORD = { };      (preferred, nixdev pattern)
          sops.secrets."REDIS/PASSWORD" = { };    (IO host pattern)
      '';
    };

    sops.templates.firecrawlEnvironment = {
      content = toShellVars (
        cfg.environment
        // {
          PORT = toString cfg.port;
          HOST = cfg.host;
          NUM_WORKERS_PER_QUEUE = toString cfg.numWorkersPerQueue;
          USE_DB_AUTHENTICATION = builtins.toJSON cfg.useDbAuthentication;
          REDIS_URL = effectiveRedisUrl;
          REDIS_RATE_LIMIT_URL = effectiveRedisRateLimitUrl;
        }
        // databaseVars
        // optionalAttrs (cfg.openrouter.enable && cfg.openrouter.modelName != null) {
          MODEL_NAME = cfg.openrouter.modelName;
        }
        // optionalAttrs (cfg.openrouter.enable && cfg.openrouter.modelEmbeddingName != null) {
          MODEL_EMBEDDING_NAME = cfg.openrouter.modelEmbeddingName;
        }
        // optionalAttrs (cfg.playwright.browsersPath != null) {
          PLAYWRIGHT_BROWSERS_PATH = "${cfg.playwright.browsersPath}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        }
      );

      restartUnits = [ "firecrawl.service" ];
    };

    systemd.services.firecrawl = {
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
      ]
      # When using repo-managed DBs (IO host model), depend on io-databases.target
      # instead of local postgresql/redis services.
      ++ optional (usingRepoPostgres || usingRepoRedis) "io-databases.target"
      # For local-only set-ups without IO DBs, keep direct service deps.
      ++ optional (!usingRepoPostgres && !usingRepoRedis && postgres != null) "postgresql.service"
      ++ optional (
        !usingRepoPostgres && !usingRepoRedis && (redis != null || redisRateLimit != null)
      ) "redis.service";
      wants = [
        "network-online.target"
      ]
      ++ optional (usingRepoPostgres || usingRepoRedis) "io-databases.target";

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
          ++ optional (cfg.bullAuthKeyFile != null) "bullAuthKey:${cfg.bullAuthKeyFile}"
          ++ optional (
            cfg.openrouter.enable && cfg.openrouter.apiKeyFile != null
          ) "openrouterKey:${cfg.openrouter.apiKeyFile}";
      };

      script = ''
        # Export BULL_AUTH_KEY from LoadCredential. FIRECRAWL_API_KEY is NOT used
        # by upstream Firecrawl for server auth (that requires Supabase) -- but we
        # still support apiKeyFile for caller compatibility without exporting it.
        if [ -f "$CREDENTIALS_DIRECTORY/bullAuthKey" ]; then
          export BULL_AUTH_KEY="$(cat "$CREDENTIALS_DIRECTORY/bullAuthKey")"
        fi
        ${lib.optionalString (cfg.openrouter.enable && cfg.openrouter.apiKeyFile != null) ''
          # Export OPENROUTER_API_KEY from LoadCredential.
          if [ -f "$CREDENTIALS_DIRECTORY/openrouterKey" ]; then
            export OPENROUTER_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/openrouterKey")"
          fi
        ''}
        exec ${getExe cfg.package}
      '';

    };

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;
  };
}

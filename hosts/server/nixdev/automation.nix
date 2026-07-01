{
  config,
  lib,
  ...
}:
let
  inherit (lib) getExe';
in
{
  sops.secrets = {
    "REDIS_PASSWORD" = { };
    "N8N/ENCRYPTION_KEY" = { };
    "N8N/RUNNER_AUTH_TOKEN" = { };
  };

  services.n8n =
    let
      sharedEnv = {
        N8N_RUNNERS_AUTH_TOKEN_FILE = config.sops.secrets."N8N/RUNNER_AUTH_TOKEN".path;
        N8N_ENCRYPTION_KEY_FILE = config.sops.secrets."N8N/ENCRYPTION_KEY".path;
      };
    in
    {
      enable = true;
      openFirewall = true;

      taskRunners = {
        enable = true;
        environment = sharedEnv // {
          N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT = 15;
          N8N_RUNNERS_MAX_CONCURRENCY = 10;
        };
        runners = {
          javascript = {
            enable = true;
            command = getExe' config.services.n8n.package "n8n-task-runner";
            healthCheckPort = 5681;
          };
          python = {
            enable = true;
            command = getExe' config.services.n8n.package "n8n-task-runner-python";
            healthCheckPort = 5682;
          };
        };
      };

      # https://github.com/n8n-io/n8n/tree/master/packages/%40n8n/config/src/configs
      environment =
        let
          postgres = config.server.database.postgres.n8n;
          redis = config.server.database.redis.n8n;
        in
        sharedEnv
        // {
          WEBHOOK_URL = "https://n8n.racci.dev/";
          N8N_PROXY_HOPS = "1";

          N8N_EDITOR_BASE_URL = "https://n8n.racci.dev";
          N8N_DEPLOYMENT_TYPE = "default";
          N8N_MFA_ENABLED = "true";

          EXECUTIONS_MODE = "regular";
          EXECUTIONS_TIMEOUT = toString (60 * 60 * 3);
          EXECUTIONS_TIMEOUT_MAX = toString (60 * 60 * 12);
          EXECUTIONS_DATA_SAVE_ON_PROGRESS = "true";
          OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS = "true";

          N8N_HIRING_BANNER_ENABLED = "false";
          N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
          N8N_DIAGNOSTICS_ENABLED = "false";

          # Database & Externals
          DB_TYPE = "postgresdb";
          DB_POSTGRESDB_DATABASE = postgres.database;
          DB_POSTGRESDB_HOST = postgres.host;
          DB_POSTGRESDB_PORT = toString postgres.port;
          DB_POSTGRESDB_USER = postgres.user;
          DB_POSTGRESDB_PASSWORD_FILE = postgres.password.path;
          QUEUE_BULL_REDIS_DB = "3";
          QUEUE_BULL_REDIS_HOST = redis.host;
          QUEUE_BULL_REDIS_PORT = toString redis.port;
          QUEUE_BULL_REDIS_PASSWORD_FILE = config.sops.secrets.REDIS_PASSWORD.path;
        };
    };

  server = {
    database = {
      postgres.n8n = { };
      redis.n8n = { };
    };

    proxy.virtualHosts = {
      n8n = {
        public = true;
        extraConfig = ''
          reverse_proxy http://0.0.0.0:${toString config.services.n8n.environment.N8N_PORT}
        '';
      };
    };
  };
}

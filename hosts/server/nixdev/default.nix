{
  config,
  ...
}:
{
  imports = [
    ./ci.nix
  ];

  services = {
    n8n = {
      enable = true;
      webhookUrl = "n8n.racci.dev";
      # https://github.com/n8n-io/n8n/blob/master/packages/%40n8n/config/src/index.ts
      environment = {
        host = "0.0.0.0";
        port = 5678;

        N8N_EDITOR_BASE_URL = "n8n.racci.dev";
        N8N_DEPLOYMENT_TYPE = "default";
        N8N_MFA_ENABLED = true;

        N8N_HIRING_BANNER_ENABLED = false;

        N8N_REDIS_KEY_PREFIX = "n8n";
        N8N_AI_ENABLED = true;

        EXECUTIONS_MODE = "queue";
        EXECUTIONS_TIMEOUT = 60 * 60 * 3;
        EXECUTIONS_TIMEOUT_MAX = 60 * 60 * 12;
        EXECUTIONS_DATA_SAVE_ON_PROGRESS = true;
      };
    };
  };

  systemd.services.n8n =
    let
      db = config.server.database.postgres.n8n;
    in
    {
      serviceConfig.LoadCredential = [ "n8n-postgres-password:${db.password.path}" ];
      environment = {
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_DATABASE = db.database;
        DB_POSTGRESDB_HOST = db.host;
        DB_POSTGRESDB_PORT = toString db.port;
        DB_POSTGRESDB_USER = db.user;
        DB_POSTGRESDB_PASSWORD_FILE = "%d/n8n-postgres-password";
      };
    };

  server = {
    database = {
      postgres = {
        n8n = { };
      };
    };

    proxy.virtualHosts = {
      n8n = {
        public = true;
        extraConfig = ''
          reverse_proxy http://0.0.0.0:5678
        '';
      };
    };
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      config.services.n8n.settings.port
      8080
      2525
    ];
  };
}

{ config, ... }:
{
  sops.secrets = {
    GITHUB_TOKEN = {
      owner = config.users.users.runner.name;
      group = config.users.groups.runner.name;
    };
    CODER_ENV = {
      owner = config.users.users.coder.name;
      inherit (config.users.users.coder) group;
    };
  };

  users = {
    users.runner = {
      name = "runner";
      group = "runner";
      isSystemUser = true;
    };

    groups.runner = {
      name = "runner";
    };
  };

  services = {
    coder = {
      enable = true;
      accessUrl = "https://coder.racci.dev";
      listenAddress = "0.0.0.0:8080";

      environment.file = config.sops.secrets.CODER_ENV.path;

      database =
        let
          db = config.server.database.postgres.coder;
        in
        {
          createLocally = false;
          inherit (db) host database;
          username = db.user;

          # This comes from the environment file
          password = "\${CODER_PASSWORD}";
        };
    };

    github-runners = {
      runner = {
        enable = true;
        user = null;
        group = null;
        url = "https://github.com/DaRacci/nix-config";
        tokenFile = config.sops.secrets.GITHUB_TOKEN.path;
      };
    };

    n8n = {
      enable = true;
      webhookUrl = "n8n.racci.dev";
      # Schema Reference https://github.com/n8n-io/n8n/blob/master/packages/cli/src/config/schema.ts
      # https://github.com/n8n-io/n8n/blob/master/packages/%40n8n/config/src/index.ts
      settings = {
        host = "0.0.0.0";
        port = 5678;
        editorBaseUrl = "n8n.racci.dev";

        deployment.type = "default";
        mfa.enabled = true;
        hiringBanner.enabled = false;
        redis.prefix = "n8n";
        ai.enabled = true;

        executions = {
          mode = "queue";
          concurrency = {
            productionLimit = -1;
            evaluationLimit = -1;
          };

          timeout = 60 * 60 * 3;
          maxTimeut = 60 * 60 * 12;

          saveDataOnError = "all";
          saveDataOnSuccess = "all";
          saveExecutionProgress = true;
          saveDataManualExecutions = true;

          queueRecovery = {
            interval = 180;
            batchSize = 100;
          };
        };

        userManagement = {
          jwtSessionDurationHours = 168;
          jwtRefreshTimeoutHours = 0;

          authenticationMethod = "email";
        };

        expression = {
          evaluator = "tournament";
          reportDifference = true;
        };
      };
    };
  };

  systemd.services.n8n =
    let
      db = config.server.database.postgres.n8n;
    in
    {
      serviceConfig.LoadCredential = [
        "n8n-postgres-password:${db.password.path}"
      ];

      environment = {
        DB_TYPE = "postgresdb";
        DB_POSTGRESDB_DATABASE = db.database;
        DB_POSTGRESDB_HOST = db.host;
        DB_POSTGRESDB_PORT = toString db.port;
        DB_POSTGRESDB_USERNAME = db.user;
        DB_POSTGRESDB_PASSWORD_FILE = "%d/n8n-postgres-password";
      };
    };

  server = {
    database.postgres = {
      n8n = { };
      coder = {
        password = {
          owner = config.users.users.coder.name;
          inherit (config.users.users.coder) group;
        };
      };
    };

    proxy.virtualHosts = {
      coder.extraConfig = ''
        reverse_proxy http://${config.services.coder.listenAddress}
      '';

      n8n.extraConfig = ''
        reverse_proxy http://${config.services.n8n.settings.host}:${toString config.services.n8n.settings.port}
      '';
    };
  };

  users.extraUsers.coder = {
    extraGroups = [ "docker" ];
  };

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      config.services.n8n.settings.port
      8080
    ];
  };
}

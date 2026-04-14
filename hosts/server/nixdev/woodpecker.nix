{
  config,
  lib,
  ...
}:
{
  sops = {
    secrets = {
      "WOODPECKER/GRPC_SECRET" = { };
      "WOODPECKER/AGENT_SECRET" = { };
      "WOODPECKER/GITHUB_CLIENT" = { };
      "WOODPECKER/GITHUB_SECRET" = { };
      "WOODPECKER/CODEBERG_CLIENT" = { };
      "WOODPECKER/CODEBERG_SECRET" = { };
    };

    templates = {
      WOODPECKER_SERVER_ENV.content =
        let
          db = config.server.database.postgres.woodpecker;
          inherit (config.sops) placeholder;
        in
        lib.toShellVars {
          WOODPECKER_DATABASE_DATASOURCE = "postgres://${db.user}:${
            placeholder."POSTGRES/WOODPECKER_PASSWORD"
          }@${db.host}:${toString db.port}/${db.database}?sslmode=disable";
          WOODPECKER_GRPC_SECRET = placeholder."WOODPECKER/AGENT_SECRET";
          WOODPECKER_AGENT_SECRET = placeholder."WOODPECKER/AGENT_SECRET";
          WOODPECKER_GITHUB_CLIENT = placeholder."WOODPECKER/GITHUB_CLIENT";
          WOODPECKER_GITHUB_SECRET = placeholder."WOODPECKER/GITHUB_SECRET";
          WOODPECKER_CODEBERG_CLIENT = placeholder."WOODPECKER/CODEBERG_CLIENT";
          WOODPECKER_CODEBERG_SECRET = placeholder."WOODPECKER/CODEBERG_SECRET";
        };

      WOODPECKER_AGENT_ENV.content =
        let
          inherit (config.sops) placeholder;
        in
        lib.toShellVars {
          WOODPECKER_AGENT_SECRET = placeholder."WOODPECKER/AGENT_SECRET";
        };
    };
  };

  server = {
    database.postgres.woodpecker = { };

    proxy.virtualHosts = {
      woodpecker = {
        public = true;
        ports = [ 8000 ];
        extraConfig = "reverse_proxy http://localhost:8000";
      };
      woodpecker-agent = {
        ports = [ 9000 ];
        extraConfig = "reverse_proxy http://localhost:9000";
      };
    };
  };

  services = {
    woodpecker-server = {
      enable = true;
      environmentFile = config.sops.templates.WOODPECKER_SERVER_ENV.path;
      environment = {
        WOODPECKER_HOST = "https://woodpecker.racci.dev";
        WOODPECKER_OPEN = "true";
        WOODPECKER_ADMIN = "DaRacci,Racci";

        WOODPECKER_DATABASE_DRIVER = "postgres";

        WOODPECKER_GITHUB = "true";
        # WOODPECKER_FORGEJO = "true";
        # WOODPECKER_FORGEJO_URL = "https://codeberg.org";

        WOODPECKER_SERVER_ADDR = ":8000";
        WOODPECKER_GRPC_ADDR = ":9000";
      };
    };

    woodpecker-agents.agents.local = {
      enable = true;
      environmentFile = [ config.sops.templates.WOODPECKER_AGENT_ENV.path ];
      extraGroups = [ "docker" ];
      environment = {
        WOODPECKER_SERVER = "localhost:9000";
        WOODPECKER_BACKEND = "docker";
        WOODPECKER_MAX_WORKFLOWS = "8";
      };
    };

    woodpeckerNix = {
      enable = true;
      isolatedStore.enable = true;
      woodpecker.agents = [ "local" ];
    };
  };
}

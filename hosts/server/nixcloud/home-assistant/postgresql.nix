{
  config,
  pkgs,
  lib,
  ...
}:
let
  db = config.server.database.postgres.hassio;
in
{
  server.database = {
    postgres = {
      hassio = { };
      hassio-agent = { };
    };
    dependentServices = [ "home-assistant" ];
  };

  sops.templates."home-assistant-db-env" = {
    owner = "hass";
    group = "hass";
    mode = "0400";
    content = "PGPASSWORD=${config.sops.placeholder."POSTGRES/HASSIO_PASSWORD"}\n";
  };

  services = {
    home-assistant = {
      extraPackages =
        ps:
        let
          inherit (ps) psycopg2;
        in
        [
          psycopg2
        ];

      config = {
        recorder.db_url = "postgresql://${db.user}@${db.host}:${toString db.port}/${db.database}";
      };
    };

    postgresql.extensions =
      ps:
      let
        inherit (ps) pgvector;
      in
      [ pgvector ];
  };

  systemd.services.home-assistant.serviceConfig.EnvironmentFile =
    config.sops.templates."home-assistant-db-env".path;

  systemd.services.postgresql-setup.serviceConfig.ExecStartPost =
    let
      sqlFile = pkgs.writeText "create-vector-extension.sql" ''
        CREATE EXTENSION IF NOT EXISTS vector;
        ALTER EXTENSION vector UPDATE;
      '';
    in
    [
      ''
        ${lib.getExe' config.services.postgresql.finalPackage "psql"} -d "${config.server.database.postgres.hassio-agent.database}" -f ${sqlFile}
      ''
    ];
}

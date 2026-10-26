{
  config,
  pkgs,
  lib,
  ...
}:
{
  server.database = {
    postgres = {
      hassio = { };
      hassio-agent = { };
    };
    dependentServices = [ "home-assistant" ];
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
        recorder.db_url = "!secret POSTGRESQL_URL";
      };
    };

    postgresql.extensions =
      ps:
      let
        inherit (ps) pgvector;
      in
      [ pgvector ];
  };

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

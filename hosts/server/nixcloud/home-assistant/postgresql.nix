{
  config,
  ...
}:
{
  server.database.postgres = {
    hassio = { };
    hassio-agent = { };
  };

  services = {
    home-assistant = {
      extraPackages =
        ps: with ps; [
          psycopg2
        ];

      config = {
        recorder.db_url = "!secret POSTGRESQL_URL";
      };
    };

    postgresql.extensions = ps: with ps; [ pgvector ];
  };

  systemd.services.postgresql-setup.serviceConfig.ExecStartPost = [
    ''
      psql -d "${config.server.database.postgres.hassio-agent.database}" -tA <<'EOF'
        CREATE EXTENSION IF NOT EXISTS vector;
        ALTER EXTENSION vector UPDATE;
      EOF
    ''
  ];
}

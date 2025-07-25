_: {
  server.database.postgres = {
    hassio = { };
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
  };
}

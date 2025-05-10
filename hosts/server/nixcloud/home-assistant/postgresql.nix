_: {
  server.database.postgres = {
    hassio = { };
  };

  services = {
    home-assistant.config = {
      recorder.db_url = "!secret POSTGRESDB_URL";
    };
  };
}

{ config, ... }:
{
  server.database.postgres = {
    hassio = { };
  };

  services = {
    home-assistant.config =
      let
        db = config.server.database.postgres.hassio;
      in
      {
        recorder.db_url = "postgresql://${db.user}@${db.host}/${db.database}";
      };
  };
}

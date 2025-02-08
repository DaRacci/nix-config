{
  services = {
    home-assistant.config = {
      recorder.db_url = "postgresql://hass@nixio/hass";
    };

    postgresql = {
      ensureDatabases = [ "hash" ];
      ensureUsers = [
        {
          name = "hash";
          ensureDBOwnership = true;
        }
      ];
    };
  };
}

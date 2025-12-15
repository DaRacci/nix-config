{
  config,
  lib,
  ...
}:
{
  sops = {
    templates.CODER_ENV.content =
      let
        cfg = config.services.coder.database;
      in
      lib.toShellVars {
        CODER_PG_CONNECTION_URL = "user=${cfg.username} password=${
          config.sops.placeholder."POSTGRES/CODER_PASSWORD"
        } database=${cfg.database} host=${cfg.host} sslmode=${cfg.sslmode}";
      };
  };

  users.extraUsers.coder = {
    extraGroups = [ "docker" ];
  };

  server = {
    database.postgres.coder = {
      password = {
        owner = config.users.users.coder.name;
        inherit (config.users.users.coder) group;
      };
    };
    proxy.virtualHosts.coder = {
      ports = [ 8080 ];
      extraConfig = ''
        reverse_proxy http://${config.services.coder.listenAddress}
      '';
    };
  };

  services.coder = {
    enable = true;
    accessUrl = "https://coder.racci.dev";
    listenAddress = "0.0.0.0:8080";

    environment.file = config.sops.templates.CODER_ENV.path;

    database =
      let
        db = config.server.database.postgres.coder;
      in
      {
        createLocally = false;
        inherit (db) host database;
        username = db.user;
      };
  };
}

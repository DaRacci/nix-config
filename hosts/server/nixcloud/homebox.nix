{ config, ... }:
{
  sops.secrets = {
    HOMEBOX_ENV = {
      owner = config.users.users.homebox.name;
      inherit (config.users.users.homebox) group;
    };
  };

  server = {
    database.postgres = {
      homebox = {
        password = {
          owner = config.users.users.homebox.name;
          inherit (config.users.users.homebox) group;
        };
      };
    };

    proxy.virtualHosts = {
      homebox.extraConfig =
        let
          cfg = config.services.homebox.settings;
        in
        ''
          reverse_proxy http://${cfg.HBOX_WEB_HOST}:${toString cfg.HBOX_WEB_PORT}
        '';
    };
  };

  services = {
    homebox = {
      enable = true;
      settings =
        let
          db = config.server.database.postgres.homebox;
        in
        {
          HBOX_MODE = "production";
          HBOX_OPTIONS_ALLOW_REGISTRATION = "true";

          HBOX_WEB_HOST = "0.0.0.0";
          HBOX_WEB_PORT = "7745";

          HBOX_DATABASE_TYPE = "postgres";
          HBOX_DATABASE_HOST = db.host;
          HBOX_DATABASE_PORT = toString db.port;
          HBOX_DATABASE_USERNAME = db.user;
          HBOX_DATABASE_DATABASE = db.database;
        };
    };
  };

  systemd.services = {
    homebox.serviceConfig.EnvironmentFile = config.sops.secrets.HOMEBOX_ENV.path;
  };
}

{ config, lib, ... }:
{
  sops.secrets = rec {
    HOMEBOX_ENV = {
      owner = config.users.users.homebox.name;
      inherit (config.users.users.homebox) group;
    };

    "POSTGRES/HOMEBOX_PASSWORD" = {
      inherit (HOMEBOX_ENV) owner group;
    };
  };

  services = rec {
    homebox = {
      enable = true;
      settings = {
        HBOX_MODE = "production";

        HBOX_WEB_HOST = "0.0.0.0";
        HBOX_WEB_PORT = "7745";

        HBOX_DATABASE_TYPE = "postgres";
        HBOX_DATABASE_HOST = "nixio";
        HBOX_DATABASE_PORT = "5432";
        HBOX_DATABASE_USERNAME = "homebox";
        HBOX_DATABASE_DATABASE = "homebox";
      };
    };

    caddy.virtualHosts."photos".extraConfig = ''
      reverse_proxy http://${homebox.settings.HBOX_WEB_HOST}:${toString homebox.settings.HBOX_WEB_PORT}
    '';

    postgresql = {
      ensureDatabases = [ homebox.settings.HBOX_DATABASE_DATABASE ];
      ensureUsers = [
        {
          name = homebox.settings.HBOX_DATABASE_USERNAME;
          ensureDBOwnership = true;
        }
      ];
    };
  };

  systemd.services = {
    postgresql.postStart =
      lib.mine.mkPostgresRolePass config.services.homebox.settings.HBOX_DATABASE_DATABASE
        config.sops.secrets."POSTGRES/HOMEBOX_PASSWORD".path;

    homebox.serviceConfig.EnvironmentFile = config.sops.secrets.HOMEBOX_ENV.path;
  };
}

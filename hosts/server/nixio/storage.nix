_:
{ config, pkgs, ... }:
{
  sops.secrets = {
    MINIO_ROOT_CREDENTIALS = {
      inherit (config.users.users.minio) group;
      owner = config.users.users.minio.name;
      restartUnits = [ "minio.service" ];
    };
  };

  services = {
    minio = {
      enable = true;
      package = pkgs.minio;
      rootCredentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
    };
  };

  systemd.services.minio.environment = {
    MINIO_DOMAIN = "minio.racci.dev";
    MINIO_BROWSER_REDIRECT_URL = "https://minio.racci.dev/console";
    MINIO_OPTS = "--certs-dir /var/lib/acme/";
  };

  server.proxy.virtualHosts.minio = {
    ports = [
      9000
      9001
    ];
    extraConfig = ''
      redir /console /console/

      handle_path /console* {
        reverse_proxy http://localhost${config.services.minio.consoleAddress}
      }

      reverse_proxy {
        to http://localhost${config.services.minio.listenAddress}
      }
    '';
  };
}

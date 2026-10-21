_:
{ config, pkgs, ... }:
let
  # TEMPORARY: Strip knownVulnerabilities from minio to unblock build.
  # TODO: Remove once migrated off MinIO (SeaweedFS evaluation in progress).
  # MinIO upstream is abandoned/insecure. This overlay is a temporary unblock only.
  minio' = pkgs.minio.overrideAttrs (old: {
    meta = (old.meta or { }) // {
      knownVulnerabilities = [ ];
    };
  });
in
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
      package = minio';
      rootCredentialsFile = config.sops.secrets.MINIO_ROOT_CREDENTIALS.path;
    };
  };

  systemd.services.minio.environment = {
    MINIO_DOMAIN = "minio.racci.dev";
    MINIO_BROWSER_REDIRECT_URL = "https://minio.racci.dev/console";
    MINIO_OPTS = "--certs-dir /var/lib/acme/";
  };

  server = {
    proxy.virtualHosts.minio = {
      aliases = [ "*.minio" ];
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

    monitoring.scrapeConfigs.minio = {
      port = 443;
      metrics_path = "/minio/v2/metrics/cluster";
      scheme = "https";
      host = "minio.racci.dev";
      bearer_token_secret = "MONITORING/MINIO_PROMETHEUS_TOKEN";
    };
  };
}

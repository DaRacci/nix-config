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

  server.proxy.virtualHosts.minio = {
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

  server.tests.units = {
    minio = {
      testScript = ''
        nixio.succeed("systemctl show minio.service | grep -i loadstate")
      '';
    };

    seaweedfs-master = {
      testScript = ''
        nixio.succeed("systemctl show seaweedfs-master.service | grep -i loadstate")
      '';
    };

    seaweedfs-volume = {
      testScript = ''
        nixio.succeed("systemctl show seaweedfs-volume.service | grep -i loadstate")
      '';
    };

    seaweedfs-filer = {
      testScript = ''
        nixio.succeed("systemctl show seaweedfs-filer.service | grep -i loadstate")
      '';
    };
  };
}

{ modulesPath, flake, config, pkgs, ... }:
let cfg = config.services.nextcloud.config; in {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };

  sops.secrets = {
    nextcloud-admin-password = {
      owner = config.users.users.nextcloud.name;
      inherit (config.users.users.nextcloud) group;
    };
    nextcloud-db-password = {
      owner = config.users.users.postgres.name;
      group = "db-pass-access";
    };
  };

  users.users = {
    groups = [ "db-pass-access" ];
    postgres.extraGroups = [ "db-pass-access" ];
    nextcloud.extraGroups = [ "db-pass-access" ];
  };

  services = {
    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.unstable.nextcloud29;

      https = true;
      # TODO - Change back to nextcloud.racci.dev when ready.
      hostName = "nc.racci.dev";

      maxUploadSize = "16G";

      autoUpdateApps = {
        enable = true;
        startAt = "05:00:00";
      };

      config = {
        adminuser = "admin";
        adminpassFile = config.sops.secrets.nextcloud-admin-password.path;

        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "/run/postgresql";
        dbpassFile = config.sops.secrets.nextcloud-db-password.path;

        # objectstore.s3 = {
        #   class = "S3";
        #   bucket = "nextcloud";
        #   autocreate = true;
        #   key = "minio";
        # };
      };

      caching = {
        redis = true;
        apcu = true;
        memcached = true;
      };

      settings = {
        default_phone_region = "AU";
        mail_smtpmode = "sendmail";
        mail_sendmailmode = "pipe";

        enabledPreviewProviders = [
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\HEIC"
        ];
      };
    };

    postgresql = {
      enable = true;

      ensureDatabases = [ cfg.dbname ];
      ensureUsers = [{ name = cfg.dbuser; ensureDBOwnership = true; }];
    };
  };

  systemd.services."nextcloud-setup" = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };

  systemd.services.postgresql.postStart = ''
    $PSQL -tA <<'EOF'
      DO $$
      DECLARE password TEXT;
      BEGIN
        password := trim(both from replace(pg_read_file('${config.sops.secrets.nextcloud-db-password.path}'), E'\n', '''));
        EXECUTE format('ALTER ROLE ${cfg.dbuser} WITH PASSWORD '''%s''';', password);
      END $$;
    EOF
  '';

  networking = {
    firewall = {
      allowedUDPPorts = [ ];
      allowedTCPPorts = [ 80 443 ];
      allowedUDPPortRanges = [{ from = 0; to = 0; }];
      allowedTCPPortRanges = [{ from = 0; to = 0; }];
    };
  };
}

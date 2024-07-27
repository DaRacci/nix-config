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

  sops.secrets = let ncOwned = { owner = config.users.users.nextcloud.name; inherit (config.users.users.nextcloud) group; }; in {
    "NEXTCLOUD/S3/SECRET" = ncOwned;
    "NEXTCLOUD/S3/SSE_CKEY" = ncOwned;
    "NEXTCLOUD/admin-password" = ncOwned;
    db-password = {
      owner = config.users.users.postgres.name;
      group = "db-pass-access";
      mode = "0440";
    };
  };

  users = {
    groups = { db-pass-access = { }; };
    users = {
      postgres.extraGroups = [ "db-pass-access" ];
      nextcloud.extraGroups = [ "db-pass-access" ];
    };
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
        adminpassFile = config.sops.secrets."NEXTCLOUD/admin-password".path;

        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "/run/postgresql";
        dbpassFile = config.sops.secrets."db-password".path;

        objectstore.s3 = {
          enable = true;
          autocreate = true;
          usePathStyle = true;

          bucket = "nextcloud";
          hostname = "nixio.racci.dev";
          key = "k6Dkuj139Y65LzvILRax";
          secretFile = config.sops.secrets."NEXTCLOUD/S3/SECRET".path;
          sseCKeyFile = config.sops.secrets."NEXTCLOUD/S3/SSE_CKEY".path;
        };
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
        password := trim(both from replace(pg_read_file('${config.sops.secrets."db-password".path}'), E'\n', '''));
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

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
    nextcloud-admin-password = { };
    nextcloud-db-password = { };
  };

  services = {
    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.unstable.nextcloud29;

      https = true;
      hostName = "nextcloud.racci.dev";

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

        defaultPhoneRegion = "AU";
        objectstore.s3 = { };
      };

      caching = {
        redis = true;
        apcu = true;
        memcached = true;
      };

      extraOptions = {
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

{ modulesPath, config, pkgs, ... }:
let cfg = config.services.nextcloud.config; in {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
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

    "POSTGRES/NEXTCLOUD_PASS" = {
      owner = config.users.users.postgres.name;
      group = "nextcloud-db-pass-access";
      mode = "0440";
    };
  };

  users = {
    groups = { nextcloud-db-pass-access = { }; };
    users = {
      postgres.extraGroups = [ "nextcloud-db-pass-access" ];
      nextcloud.extraGroups = [ "nextcloud-db-pass-access" ];
    };
  };

  services = rec {
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
        dbpassFile = config.sops.secrets."POSTGRES/NEXTCLOUD_PASS".path;

        objectstore.s3 = {
          enable = true;
          autocreate = true;
          usePathStyle = true;

          bucket = "nextcloud";
          region = "us-east-1";
          hostname = "minio.racci.dev";
          key = "k6Dkuj139Y65LzvILRax";
          secretFile = config.sops.secrets."NEXTCLOUD/S3/SECRET".path;
          # sseCKeyFile = config.sops.secrets."NEXTCLOUD/S3/SSE_CKEY".path;
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
          "OC\\Preview\\Imaginary"
          # "OC\\Preview\\BMP"
          # "OC\\Preview\\GIF"
          # "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          # "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          # "OC\\Preview\\XBitmap"
          # "OC\\Preview\\HEIC"
        ];

        trusted_proxies = [
          "192.168.1.0/24"
          "192.168.2.0/24"
        ];
      };

      phpOptions = {
        maintenance_window_start = "100";

        preview_imaginary_url = "http://127.0.0.1:${toString imaginary.port}";

        "opcache.jit" = "1255";
        "opcache.jit_buffer_size" = "128M";
      };

      notify_push = {
        enable = true;
        package = pkgs.nextcloud-notify_push;
        bendDomainToLocalhost = true;
      };
    };

    imaginary = {
      enable = true;
      port = 9000;
      settings = {
        concurrency = 50;
        enable-url-source = true;
        return-size = true;
        max-allowed-resolution = "222.2";
        allowed-origins = [ "https://${nextcloud.hostName}" ];
      };
    };

    clamav = {
      daemon = {
        enable = true;
        settings = {
          MaxDirectoryRecursion = 30;
          MaxFileSize = "10G";
          PCREMaxFileSize = "10G";
          StreamMaxLength = "10G";
        };
      };

      updater.enable = true;
    };

    elasticsearch = {
      enable = true;
      package = pkgs.elasticsearch;
      port = 9200;
      plugins = [ pkgs.elasticsearchPlugins.ingest-attachment ];
    };

    postgresql = {
      enable = true;

      ensureDatabases = [
        nextcloud.config.dbname
      ];
      ensureUsers = [
        { name = nextcloud.config.dbuser; ensureDBOwnership = true; }
      ];
    };

    caddy.virtualHosts."nc.racci.dev".extraConfig = /*caddyfile*/ ''
      reverse_proxy http://localhost:80
    '';
  };

  virtualisation.docker = {
    enable = true;
  };

  systemd.services = {
    nextcloud-setup = {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
    };

    postgresql.postStart = ''
      $PSQL -tA <<'EOF'
        DO $$
        DECLARE password TEXT;
        BEGIN
          password := trim(both from replace(pg_read_file('${config.sops.secrets."POSTGRES/NEXTCLOUD_PASS".path}'), E'\n', '''));
          EXECUTE format('ALTER ROLE ${cfg.dbuser} WITH PASSWORD '''%s''';', password);
        END $$;
      EOF
    '';

    protonmail-bridge = {
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      script = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --no-window --noninteractive --log-level info";

      serviceConfig = {
        Restart = "always";
      };
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 3478 ];
      allowedTCPPorts = [ 80 443 3478 ];
    };
  };
}

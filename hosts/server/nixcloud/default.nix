{ modulesPath, config, pkgs, lib, ... }: {
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

    "POSTGRES/NEXTCLOUD_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.nextcloud-db-pass-access.name;
      mode = "0440";
    };

    "POSTGRES/IMMICH_PASSWORD" = {
      owner = config.users.users.postgres.name;
      group = config.users.groups.immich-db-pass-access.name;
      mode = "0440";
    };

    "IMMICH/ENV" = {
      owner = config.users.users.immich.name;
      inherit (config.users.users.immich) group;
    };
  };

  users = {
    groups = {
      nextcloud-db-pass-access = { };
      immich-db-pass-access = { };
    };
    users = {
      postgres.extraGroups = [ "nextcloud-db-pass-access" "immich-db-pass-access" ];
      nextcloud.extraGroups = [ "nextcloud-db-pass-access" ];
      immich.extraGroups = [ "immich-db-pass-access" ];
    };
  };

  services = rec {
    immich = {
      enable = true;
      host = "127.0.0.1";
      secretsFile = config.sops.secrets."IMMICH/ENV".path;
      environment = {
        IMMICH_TRUSTED_PROXIES = "100.64.0.0/10,192.168.1.0/24,192.168.2.0/24";
      };

      machine-learning = {
        enable = true;
        environment = { };
      };

      database = {
        enable = true;
        createDB = true;
      };

      redis = {
        enable = true;
      };
    };

    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.nextcloud30;

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
        dbpassFile = config.sops.secrets."POSTGRES/NEXTCLOUD_PASSWORD".path;

        objectstore.s3 = {
          enable = true;
          autocreate = true;
          usePathStyle = true;

          bucket = "nextcloud";
          region = "us-east-1";
          hostname = "minio.racci.dev";
          key = "k6Dkuj139Y65LzvILRax";
          secretFile = config.sops.secrets."NEXTCLOUD/S3/SECRET".path;
          # sseCKeyFile = config.sops.secrets."NEXTCLOUD/S3/SSE_CKEY".path; // TODO - Uncomment when ready.
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
        # max-allowed-resolution = "222.2";
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

      ensureDatabases = [ nextcloud.config.dbname ];
      ensureUsers = [{ name = nextcloud.config.dbuser; ensureDBOwnership = true; }];
    };

    caddy.virtualHosts = {
      "nc".extraConfig = /*caddyfile*/ ''
        reverse_proxy http://localhost:80
      '';

      "photos".extraConfig = let cfg = config.services.immich; in /*caddyfile*/ ''
        reverse_proxy http://${cfg.host}:${toString cfg.port}
      '';
    };
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
      ${lib.mine.mkPostgresRolePass config.services.nextcloud.config.dbname config.sops.secrets."POSTGRES/NEXTCLOUD_PASSWORD".path}
      ${lib.mine.mkPostgresRolePass config.services.immich.database.name config.sops.secrets."POSTGRES/IMMICH_PASSWORD".path}
    '';

    # protonmail-bridge = {
    #   after = [ "network.target" ];
    #   wantedBy = [ "default.target" ];
    #   script = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --no-window --noninteractive --log-level info";

    #   serviceConfig = {
    #     Restart = "always";
    #   };
    # };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 3478 ];
      allowedTCPPorts = [
        # Nextcloud
        80
        443
        3478

        # Immich
        config.services.immich.port
      ];
    };
  };
}

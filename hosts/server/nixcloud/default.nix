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
    "IMMICH/S3FS_AUTH" = { };
  };

  users = {
    groups = {
      nextcloud-db-pass-access = { };
      immich-db-pass-access = { };
      immich.gid = 998;
    };
    users = {
      postgres.extraGroups = [ "nextcloud-db-pass-access" "immich-db-pass-access" ];
      nextcloud.extraGroups = [ "nextcloud-db-pass-access" ];
      immich = {
        uid = 998;
        extraGroups = [ "immich-db-pass-access" ];
      };
    };
  };

  services = rec {
    immich = {
      enable = true;
      host = "0.0.0.0";
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
        host = "nixio";
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

      caching = {
        redis = true;
        apcu = true;
        memcached = true;
      };

      config = {
        adminuser = "admin";
        adminpassFile = config.sops.secrets."NEXTCLOUD/admin-password".path;

        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "nixio";
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

      settings = {
        default_phone_region = "AU";
        maintenance_window_start = 15; # 2 AM Sydney time
        log_type = "file";

        mail_from_address = "no-reply";
        mail_domain = "racci.dev";
        mail_smtpmode = "sendmail";
        mail_sendmailmode = "pipe";

        preview_imaginary_url = "http://127.0.0.1:${toString imaginary.port}";
        enabledPreviewProviders = [
          "OC\\Preview\\Imaginary"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\TXT"
        ];

        trusted_proxies = [
          "192.168.1.0/24"
          "192.168.2.0/24"
          "100.64.0.0/10"
        ];

        twofactor_enforced = true;
        twofactor_enforced_groups = [ ];
      };

      phpOptions = {
        "opcache.jit" = "1255";
        "opcache.jit_buffer_size" = "8M";
        "opcache.memory_consumption" = 256;
        "opcache.interned_strings_buffer" = 64;
        "opcache.save_comments" = 1;
        "opcache.revalidate_freq" = 60;
      };

      # Just copied what AIO provides.
      phpExtraExtensions = all: with all; [
        pdlib
        bcmath
        exif
        ftp
        gd
        gmp
        igbinary
        imap
        ldap
        pcntl
        pdo_pgsql
        pgsql
        smbclient
        sysvsem
        zip
      ];

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
      enable = lib.mkForce false;

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

    protonmail-bridge.enable = true;
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

    protonmail-bridge = {
      after = lib.mkForce [ "network.target" ];
      wantedBy = lib.mkForce [ "default.target" ];
    };
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

  environment.systemPackages = [ pkgs.s3fs ];

  fileSystems."nextcloud" = {
    device = "${lib.getExe' pkgs.s3fs "s3fs"}#nextcloud";
    mountPoint = "/var/lib/immich/ext/nextcloud";
    fsType = "fuse";
    noCheck = true;
    options = [ "_netdev" "allow_other" "use_path_request_style" "url=https://minio.racci.dev" "passwd_file=${config.sops.secrets."IMMICH/S3FS_AUTH".path}" "umask=0007" "mp_umask=0007" "nonempty" "uid=${toString config.users.users.immich.uid}" "gid=${toString config.users.groups.immich.gid}" ];
  };
}

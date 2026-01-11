{
  config,
  pkgs,
  ...
}:
let
  ncOwned = {
    owner = config.users.users.nextcloud.name;
    inherit (config.users.users.nextcloud) group;
  };
in
{
  users = {
    users.nextcloud = {
      group = "nextcloud";
      uid = 997;
      extraGroups = [ "docker" ];
    };

    groups.nextcloud.gid = 997;
  };

  sops.secrets = {
    "NEXTCLOUD/admin-password" = ncOwned;
  };

  server = {
    database = {
      postgres.nextcloud.password = ncOwned;
      dependentServices = [ "phpfpm-nextcloud" ];
    };

    dashboard.items.nc = {
      title = "Nextcloud";
      icon = "sh-nextcloud";
    };

    proxy.virtualHosts.nc = {
      public = true;
      extraConfig = ''
        reverse_proxy http://localhost:80
      '';
    };

    storage.bucketMounts = {
      nextcloud = {
        mountLocation = "/var/lib/nextcloud/data";
        inherit (config.users.users.nextcloud) uid;
        inherit (config.users.groups.nextcloud) gid;
      };
    };
  };

  services = rec {
    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.nextcloud32;
      appstoreEnable = false;
      extraAppsEnable = true;
      extraApps = {
        # TODO files_antivirus,checksum,assistant,files_fulltextsearch
        inherit (config.services.nextcloud.package.packages.apps)
          calendar
          contacts
          deck
          files_automatedtagging
          forms
          groupfolders
          impersonate
          notes
          previewgenerator
          spreed
          tasks
          twofactor_webauthn
          user_oidc
          ;
      };

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

      config =
        let
          db = config.server.database.postgres.nextcloud;
        in
        {
          adminuser = "admin";
          adminpassFile = config.sops.secrets."NEXTCLOUD/admin-password".path;

          dbtype = "pgsql";
          dbuser = db.user;
          dbname = db.database;
          dbhost = db.host;
          dbpassFile = db.password.path;
        };

      settings = {
        default_phone_region = "AU";
        maintenance_window_start = 15; # 2 AM Sydney time
        log_type = "file";

        mail_domain = "racci.dev";
        mail_from_address = "no-reply";
        mail_smtpmode = "smtp";
        mail_smtphost = "mail.protonmail.ch";
        mail_smtpport = 25;

        mail_smtpstreamoptions = {
          ssl = {
            allow_self_signed = true;
            verify_peer = false;
            verify_peer_name = false;
          };
        };

        preview_imaginary_url = "http://127.0.0.1:${toString imaginary.port}";
        enabledPreviewProviders = [
          "OC\\Preview\\Imaginary"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\TXT"
        ];

        allow_local_remote_servers = true;
        trusted_proxies = [
          "::1" # For notify_push
        ]
        ++ (config.server.network.subnets |> builtins.map (v: v.ipv4.cidr));

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
      phpExtraExtensions =
        all: with all; [
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
        nextcloudUrl = "http://localhost:80";
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
  };

  virtualisation.docker.enable = true;

  networking = {
    firewall = {
      allowedUDPPorts = [ 3478 ];
      allowedTCPPorts = [
        80
        443
        3478
      ];
    };
  };
}

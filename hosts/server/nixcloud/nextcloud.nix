{
  config,
  pkgs,
  lib,
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

    users.protonmail-bridge = {
      home = "/var/lib/protonmail-bridge";
      group = "protonmail-bridge";
      createHome = true;
      uid = 385;
    };
    groups.protonmail-bridge.members = [ "protonmail-bridge" ];
  };

  sops.secrets = {
    "NEXTCLOUD/admin-password" = ncOwned;
    "NEXTCLOUD/S3FS_AUTH" = ncOwned;
  };

  server = {
    database.postgres = {
      nextcloud = {
        password = ncOwned;
      };
    };

    proxy.virtualHosts = {
      "nc".extraConfig = ''
        reverse_proxy http://localhost:80
      '';
    };
  };

  services = rec {
    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.nextcloud31;
      appstoreEnable = true;
      extraAppsEnable = true;
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          contacts
          calendar
          groupfolders
          impersonate
          notes
          notify_push
          spreed
          tasks
          twofactor_webauthn
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

    passSecretService.enable = true;
  };

  virtualisation.docker.enable = true;

  systemd.services = {
    protonmail-bridge = {
      after = lib.mkForce [ "network.target" ];
      wantedBy = lib.mkForce [ "default.target" ];
      script = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --no-window --noninteractive --log-level info";
      path = [ pkgs.pass ];

      serviceConfig = {
        Restart = "always";
        RestartSec = "5";
        User = config.users.users.protonmail-bridge.name;
      };
    };
  };

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

  environment.systemPackages = [ pkgs.s3fs ];

  fileSystems."nextcloud" = {
    device = "${lib.getExe' pkgs.s3fs "s3fs"}#nextcloud";
    mountPoint = "/var/lib/nextcloud/data";
    fsType = "fuse";
    noCheck = true;
    options = [
      "_netdev"
      "allow_other"
      "use_path_request_style"
      "url=https://minio.racci.dev"
      "passwd_file=${config.sops.secrets."NEXTCLOUD/S3FS_AUTH".path}"
      "umask=0007"
      "mp_umask=0007"
      "nonempty"
      "uid=${toString config.users.users.nextcloud.uid}"
      "gid=${toString config.users.groups.nextcloud.gid}"
    ];
  };
}

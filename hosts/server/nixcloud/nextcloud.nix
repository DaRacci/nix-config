{ config, pkgs, lib, ... }: {
  services = rec {
    nextcloud = {
      enable = true;
      configureRedis = true;
      package = pkgs.nextcloud30;
      appstoreEnable = true;
      extraAppsEnable = true;
      extraApps = {
        inherit (config.services.nextcloud.package.packages.apps)
          contacts
          calendar
          groupfolders
          impersonate
          maps
          notes
          notify_push
          spreed
          tasks
          twofactor_webauthn;
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

      config = {
        adminuser = "admin";
        adminpassFile = config.sops.secrets."NEXTCLOUD/admin-password".path;

        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "nixio";
        dbpassFile = config.sops.secrets."POSTGRES/NEXTCLOUD_PASSWORD".path;
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
      ensureDatabases = [ nextcloud.config.dbname ];
      ensureUsers = [{ name = nextcloud.config.dbuser; ensureDBOwnership = true; }];
    };

    caddy.virtualHosts."nc".extraConfig = /*caddyfile*/ ''
      reverse_proxy http://localhost:80
    '';
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

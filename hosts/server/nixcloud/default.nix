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

  tailscale.enable = true;

  sops.secrets = {
    nextcloud-admin-password = { };
    nextcloud-db-password = { };
  };

  services.nextcloud = {
    enable = true;
    configureRedis = true;
    package = pkgs.nextcloud28;

    https = true;
    hostName = "nextcloud.racci.dev";

    maxUploadSize = "10G";

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
      dbpassFile = config.sops.secrets.nextcloud-db-pass.path;
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

  services.postgresql = {
    enable = true;

    ensureDatabases = [ cfg.dbname ];
    ensureUsers = [{ name = cfg.dbuser; ensurePermissions."DATABASE ${cfg.dbname}" = "ALL PRIVILEGES"; }];
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
        password := trim(both from replace(pg_read_file('${config.sops.secrets.nextcloud-db-pass.path}'), E'\n', '''));
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

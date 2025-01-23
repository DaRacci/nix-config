{ modulesPath, config, pkgs, lib, ... }: {
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };

  sops.secrets =
    let
      ncOwned = { owner = config.users.users.nextcloud.name; inherit (config.users.users.nextcloud) group; };
      immichOwned = { owner = config.users.users.immich.name; inherit (config.users.users.immich) group; };
    in
    {
      "NEXTCLOUD/admin-password" = ncOwned;
      "NEXTCLOUD/S3FS_AUTH" = ncOwned;

      "POSTGRES/NEXTCLOUD_PASSWORD" = ncOwned;
      "POSTGRES/IMMICH_PASSWORD" = immichOwned;

      "IMMICH/ENV" = immichOwned;
    };

  users = {
    groups = {
      immich.gid = 998;
      nextcloud.gid = 997;
    };
    users = {
      immich.uid = 998;
      nextcloud = {
        uid = 997;
        extraGroups = [ "docker" ];
      };
    };

    users.protonmail-bridge = {
      isSystemUser = true;
      home = "/var/lib/protonmail-bridge";
      group = "protonmail-bridge";
      createHome = true;
    };
    groups.protonmail-bridge.members = [ "protonmail-bridge" ];
  };

  services = {
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

    caddy.virtualHosts = {
      "photos".extraConfig = let cfg = config.services.immich; in /*caddyfile*/ ''
        reverse_proxy http://${cfg.host}:${toString cfg.port}
      '';
    };

    passSecretService.enable = true;
  };

  virtualisation.docker.enable = true;

  systemd.services = {
    postgresql = {
      enable = lib.mkForce false;
      postStart = ''
        ${lib.mine.mkPostgresRolePass config.services.nextcloud.config.dbname config.sops.secrets."POSTGRES/NEXTCLOUD_PASSWORD".path}
        ${lib.mine.mkPostgresRolePass config.services.immich.database.name config.sops.secrets."POSTGRES/IMMICH_PASSWORD".path}
      '';
    };

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
      allowedTCPPorts = [
        config.services.immich.port
      ];
    };
  };
}

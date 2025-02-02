{ config, lib, ... }:
{
  users = {
    users.immich.uid = 998;
    groups.immich.gid = 998;
  };

  sops.secrets =
    let
      immichOwned = {
        owner = config.users.users.immich.name;
        inherit (config.users.users.immich) group;
      };
    in
    {
      "POSTGRES/IMMICH_PASSWORD" = immichOwned;
      "IMMICH/ENV" = immichOwned;
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

    caddy.virtualHosts."photos".extraConfig =
      let
        cfg = config.services.immich;
      in
      ''
        reverse_proxy http://${cfg.host}:${toString cfg.port}
      '';
  };

  systemd.services = {
    postgresql = {
      enable = lib.mkForce false;
      postStart = ''
        ${lib.mine.mkPostgresRolePass config.services.immich.database.name
          config.sops.secrets."POSTGRES/IMMICH_PASSWORD".path
        }
      '';
    };
  };

  networking = {
    firewall = {
      allowedTCPPorts = [ config.services.immich.port ];
    };
  };
}

{ config, lib, ... }:
let
  immichOwned = {
    owner = config.users.users.immich.name;
    inherit (config.users.users.immich) group;
  };
in
{
  users = {
    users.immich.uid = 998;
    groups.immich.gid = 998;
  };

  sops.secrets = {
    "IMMICH/ENV" = immichOwned;
  };

  server = {
    database.postgres.immich = {
      password = immichOwned;
    };

    dashboard.items.photos = {
      title = "Immich";
      icon = "sh-immich";
    };

    proxy.virtualHosts.photos.extraConfig =
      let
        cfg = config.services.immich;
      in
      ''
        reverse_proxy http://${cfg.host}:${toString cfg.port}
      '';

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

      database =
        let
          db = config.server.database.postgres.immich;
        in
        {
          inherit (db)
            host
            port
            user
            ;

          enableVectors = false; # Will be removed in future versions
          enableVectorChord = true;
        };

      redis = {
        enable = true;
      };
    };
    postgresql.enable = lib.mkForce false;
  };

  networking = {
    firewall = {
      allowedTCPPorts = [ config.services.immich.port ];
    };
  };
}

{ config, ... }: {
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

    caddy.virtualHosts."photos".extraConfig = let cfg = config.services.immich; in /*caddyfile*/ ''
      reverse_proxy http://${cfg.host}:${toString cfg.port}
    '';
  };
}

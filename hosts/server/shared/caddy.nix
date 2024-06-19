{ config, pkgs, ... }: {
  services.caddy = {
    package = pkgs.unstable.caddy;
    email = "admin@racci.dev";
    acmeCA = "https://acme-v02.api.letsencrypt.org/directory";

    logFormat = ''
      level DEBUG
      format console
    '';

    # globalConfig = ''
    #   acme_dns cloudflare {$CLOUDFLARE_API_TOKEN}
    # '';
  };

  systemd.services.caddy = {
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.CLOUDFLARE_API_TOKEN.path;
    };
  };
}

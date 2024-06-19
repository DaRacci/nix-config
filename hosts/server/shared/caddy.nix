{ config, pkgs, ... }: {
  services.caddy = {
    package = pkgs.caddy;
    email = "admin@racci.dev";
    acmeCA = "https://acme-v02.api.letsencrypt.org/directory";

    logFormat = ''
      level DEBUG
      format console
    '';

    globalConfig = ''
      tls {
        acme_dns cloudflare ${config.sops.secrets.CLOUDFLARE_API_TOKEN}
      }
    '';
  };
}

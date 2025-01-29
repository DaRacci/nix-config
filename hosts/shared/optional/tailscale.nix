{
  flake,
  config,
  pkgs,
  ...
}:
{
  sops.secrets.TAILSCALE_AUTH_KEY = {
    sopsFile = "${flake}/hosts/secrets.yaml";
  };

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets.TAILSCALE_AUTH_KEY.path;
  };

  host.persistence.directories = [ "/var/lib/tailscale" ];
}

{
  self,
  config,
  pkgs,
  ...
}:
{
  sops.secrets.TAILSCALE_AUTH_KEY = {
    sopsFile = "${self}/hosts/secrets.yaml";
    restartUnits = [
      "tailscaled-autoconnect.service"
      "tailscaled.service"
    ];
  };

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets.TAILSCALE_AUTH_KEY.path;
    extraDaemonFlags = [ "--no-logs-no-support" ];
    extraUpFlags = [
      "--accept-dns=true"
      "--accept-routes"
    ];
  };

  host.persistence.directories = [ "/var/lib/tailscale" ];
}

{ pkgs, ... }: {
  services.tailscale = {
    enable = true;
    package = pkgs.unstable.tailscale;
    useRoutingFeatures = "client";
  };

  host.persistence.directories = [
    "/var/lib/tailscale"
  ];
}

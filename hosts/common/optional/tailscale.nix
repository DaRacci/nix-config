{ ... }: {
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  host.persistence.directories = [
    "/var/lib/tailscale"
  ];
}

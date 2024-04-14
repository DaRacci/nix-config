{ image ? "caddy"
, version ? "latest"
, ...
}: {
  networks.proxy = {
    name = "proxy";
    internal = true;
    attachable = false;
    enable_ipv6 = false; # TODO :: Learn IPv6
    ipam.config = [{
      subnet = "10.10.10.0/24";
      ip_range = "10.10.10.128/25";
      gateway = "10.10.10.1";
    }];
  };

  services.caddy = _: {
    service = {
      image = "${image}:${version}";
      volumes = [ "${toString ./.}/Caddyfile:/etc/caddy/Caddyfile:ro" ];

      networks = [ "proxy" ];
      ports = [ "80:80/tcp" "443:443/tcp" ];

      environment = {
        EMAIL = "admin@racci.dev";
        DOMAIN = "racci.dev";
      };
    };
  };
}

let
  image = "caddy:alpine";
in rec {
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

  services.caddy = { pkgs, lib, ... }: {
    service = {
      inherit image;
      volumes = [ "${toString ./.}/Caddyfile:/etc/caddy/Caddyfile:ro" ];

      networks = [ "proxy" ];
      ports = [ "80:80/tcp" "443:443/tcp" ];

      environment = {
        EMAIL = "admin@racci.dev";
        DOMAIN = "home";
      };
    };
  };
}
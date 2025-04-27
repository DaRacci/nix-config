{ pkgs, ... }:
{
  imports = [
    ./postgresql.nix
    ./weather.nix
    ./zones.nix
  ];

  sops.secrets."home-assistant-secrets.yaml" = {
    owner = "hash";
    path = "/var/lib/hass/secrets.yaml";
    restartUnits = [ "home-assistant.service" ];
  };

  server.proxy.virtualHosts = {
    hassio.extraConfig = ''
      reverse_proxy http://localhost:8123
    '';
  };

  services = {
    home-assistant = {
      enable = true;
      openFirewall = true;
      package = pkgs.home-assistant.override { extraPackages = ps: [ ps.psycopg2 ]; };

      config = {
        http = {
          server_host = "::1";
          trusted_proxies = [ "::1" ];
          use_x_forwarded_for = true;
        };

        frontend = { };
        history = { };
      };
    };
  };
}

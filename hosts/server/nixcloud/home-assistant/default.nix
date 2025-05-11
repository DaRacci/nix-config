{ pkgs, ... }:
{
  imports = [
    ./postgresql.nix
    ./proxy.nix
    # ./weather.nix
    ./zones.nix
  ];

  sops.secrets."home-assistant-secrets.yaml" = {
    sopsFile = ./secrets.yaml;
    key = "";
    owner = "hass";
    path = "/var/lib/hass/secrets.yaml";
    restartUnits = [ "home-assistant.service" ];
  };

  services = {
    home-assistant = {
      enable = true;
      openFirewall = true;
      package = pkgs.home-assistant.override { extraPackages = ps: [ ps.psycopg2 ]; };

      config = {
        frontend = { };
        history = { };
      };
    };
  };
}

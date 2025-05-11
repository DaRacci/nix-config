{
  config,
  pkgs,
  ...
}:
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
      package = pkgs.home-assistant.override { extraPackages = ps: [ ps.psycopg2 ]; };

      configWritable = true;
      config = {
        frontend = { };
        history = { };

        isal = { };

        "automation manual" = [ ];
        "automation ui" = "!include automations.yaml";
        "scene manual" = [ ];
        "scene ui" = "!include scenes.yaml";
      };
    };
  };

  # https://nixos.wiki/wiki/Home_Assistant#Combine_declarative_and_UI_defined_automations
  systemd.tmpfiles.rules = [
    "f ${config.services.home-assistant.configDir}/automations.yaml 0755 hass hass"
    "f ${config.services.home-assistant.configDir}/scenes.yaml 0755 hass hass"
  ];
}

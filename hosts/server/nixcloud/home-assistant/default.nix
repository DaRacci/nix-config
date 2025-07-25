{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./connections.nix
    ./connectivity.nix
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
      package = pkgs.home-assistant.override {
        extraPackages =
          ps: with ps; [
            aiogithubapi
            pynetgear
            google-nest-sdm
            pyarlo
            pkgs.ssh-terminal-manager
            pkgs.pyuptimekuma
            spotifyaio
          ];
      };
      customComponents = with pkgs.home-assistant-custom-components; [
        moonraker
        waste_collection_schedule
        philips_airpurifier_coap
        smartir
        sleep_as_android
      ];
      customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
        weather-chart-card
        versatile-thermostat-ui-card
        vacuum-card
        decluttering-card
        universal-remote-card
        plotly-chart-card
        mushroom
        mini-media-player
        mini-graph-card
        hourly-weather
        clock-weather-card
        bubble-card
        auto-entities
        card-mod
      ];

      configWritable = true;
      config = {
        frontend = { };
        default_config = { };

        isal = { };

        "automation manual" = [ ];
        "automation ui" = "!include automations.yaml";
        "scene manual" = [ ];
        "scene ui" = "!include scenes.yaml";

        lovelace.mode = "yaml";
      };
    };
  };

  # https://nixos.wiki/wiki/Home_Assistant#Combine_declarative_and_UI_defined_automations
  systemd.tmpfiles.rules = [
    "f ${config.services.home-assistant.configDir}/automations.yaml 0755 hass hass"
    "f ${config.services.home-assistant.configDir}/scenes.yaml 0755 hass hass"
  ];
}

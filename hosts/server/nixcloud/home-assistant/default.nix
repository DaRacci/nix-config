{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./connections.nix
    ./connectivity.nix
    ./dashboard.nix
    ./music.nix
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
    avahi = {
      enable = true;
    };

    home-assistant = {
      enable = true;
      package = pkgs.home-assistant.override {
        extraPackages =
          ps: with ps; [
            aiogithubapi
            pynetgear
            google-nest-sdm
            pkgs.ssh-terminal-manager
            pkgs.pyuptimekuma
            pkgs.pyarlo
            spotifyaio

            aiobotocore # For S3 Backup to Minio
          ];
      };
      customComponents = with pkgs.home-assistant-custom-components; [
        moonraker
        waste_collection_schedule
        philips_airpurifier_coap
        smartir
        sleep_as_android
      ];

      configWritable = true;
      config = {
        frontend = { };
        default_config = { };
        zeroconf = { };

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

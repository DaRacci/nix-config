{
  config,
  pkgs,
  ...
}:
let
  inherit (pkgs.home-assistant-custom-components)
    philips_airpurifier_coap
    smartir
    waste_collection_schedule
    ;
in
{
  imports = [
    ./connections.nix
    ./connectivity.nix
    ./dashboard.nix
    ./dashboard
    ./monitoring.nix
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
          ps:
          let
            inherit (ps)
              aiogithubapi
              google-nest-sdm
              grpcio
              langchain
              langchain-core
              langchain-google-genai
              langchain-ollama
              langchain-openai
              langgraph
              langgraph-checkpoint-postgres
              ollama
              openai
              pynetgear
              spotifyaio
              transformers
              ;
          in
          [
            aiogithubapi
            pynetgear
            google-nest-sdm
            pkgs.ssh-terminal-manager
            pkgs.pyuptimekuma
            pkgs.pyarlo
            spotifyaio

            pkgs.python3Packages.aiobotocore # For S3 Backup to Minio

            # Required for home-generative-agent integration
            # Source: https://github.com/goruck/home-generative-agent/blob/main/custom_components/home_generative_agent/manifest.json
            grpcio
            openai
            ollama
            transformers
            langgraph
            langgraph-checkpoint-postgres
            langchain
            langchain-core
            langchain-ollama
            langchain-openai
            langchain-google-genai
          ];
      };
      customComponents = [
        #TODO:https://github.com/marcolivierarsenault/moonraker-home-assistant/issues/789
        # moonraker
        waste_collection_schedule
        philips_airpurifier_coap
        smartir
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
        "script manual" = [ ];
        "script ui" = "!include scripts.yaml";
      };
    };
  };

  # https://nixos.wiki/wiki/Home_Assistant#Combine_declarative_and_UI_defined_automations
  systemd.tmpfiles.rules = [
    "f ${config.services.home-assistant.configDir}/automations.yaml 0755 hass hass"
    "f ${config.services.home-assistant.configDir}/scenes.yaml 0755 hass hass"
  ];
}

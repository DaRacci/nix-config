{
  pkgs,
  ...
}:
{
  services.home-assistant = {
    customComponents = with pkgs.home-assistant-custom-components; [
      auth_oidc
    ];

    extraComponents = [
      # Service Connections
      "openweathermap"
      "met"
      "sun"
      "caldav"
      "speedtestdotnet"
      "openai_conversation"
      "uptime_kuma"

      # Network Stuff
      "adguard"
      "unifi"

      # Devices
      "alexa_devices"
      "androidtv"
      "androidtv_remote"
      "apple_tv"
      "cast"
      "govee_light_local"
      "homekit"
      "homekit_controller"
      "mobile_app"
      "schlage"
      "sensibo"
      "tile"
      "tplink"
      "unifiprotect"
      "zha"

      # Arr Suite
      "radarr"
      "sonarr"
      "jellyfin"
      "transmission"

      # Assistant
      "ollama"
      "rhasspy"
      "wyoming"
      "mcp"
      "mcp_server"
    ];

    config.auth_oidc = {
      client_id = "hassio";
      client_secret = "!secret OIDC_SECRET";
      discovery_url = "https://auth.racci.dev/oauth2/openid/hassio/.well-known/openid-configuration";
      features.automatic_user_linking = true;
      id_token_signing_alg = "ES256";
      roles = {
        admin = "sysadmin@auth.racci.dev";
        user = "family@auth.racci.dev";
      };
      claims = {
        display_name = "displayname";
        username = "name";
      };
    };
  };
}

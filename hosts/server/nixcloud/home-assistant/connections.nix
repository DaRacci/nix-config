_: {
  services.home-assistant = {
    extraComponents = [
      # Service Connections
      "openweathermap"
      "met"
      "sun"
      "caldav"

      # Network Stuff
      "adguard"
      "unifi"

      # Devices
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

      # Assistant
      "ollama"
      "rhasspy"
      "wyoming"
      "mcp"
      "mcp_server"
    ];
  };
}

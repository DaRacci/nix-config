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
      "cast"
      "apple_tv"
      "schlage"
      "sensibo"
      "tile"
      "tplink"
      "unifiprotect"
      "mobile_app"
      "homekit"
      "homekit_controller"
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

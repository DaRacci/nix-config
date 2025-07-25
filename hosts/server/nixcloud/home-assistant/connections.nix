_: {
  services.home-assistant = {
    extraComponents = [
      # Service Connections
      "openweathermap"
      "sun"
      "caldav"

      # Network Stuff
      "adguard"
      "unifi"

      # Devices
      "androidtv"
      "androidtv_remote"
      "apple_tv"
      "schlage"
      "sensibo"
      "tile"
      "tplink"
      "unifiprotect"
      "mobile_app"

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

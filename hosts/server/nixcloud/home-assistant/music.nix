_: {
  services = {
    home-assistant = {
      extraComponents = [ "music_assistant" ];
    };

    music-assistant = {
      enable = true;
      providers = [
        "chromecast"
        "hass"
        "hass_players"
        "jellyfin"
        "spotify"
        "spotify_connect"
        "ytmusic"
      ];
    };
  };

  server.proxy.virtualHosts.music = {
    ports = [
      8095 # UI
      8097 # Seems to be used for auth callbacks.
      8098 # Stream Server
    ];
    extraConfig = ''
      reverse_proxy http://localhost:8095
    '';
  };
}

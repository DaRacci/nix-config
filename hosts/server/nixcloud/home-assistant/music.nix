_: {
  services = {
    home-assistant = {
      extraComponents = [ "music_assistant" ];
    };

    music-assistant = {
      enable = true;
      providers = [
        "airplay"
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
}

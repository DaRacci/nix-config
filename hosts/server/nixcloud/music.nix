{
  config,
  ...
}:
{
  services = {
    navidrome = {
      enable = true;
      settings = {
        Address = "0.0.0.0";
        BaseUrl = "https://music.racci.dev";
        MusicFolder = "/mnt/media/library/music";
      };
    };
  };

  server.proxy.virtualHosts = {
    music = {
      public = true;
      extraConfig = ''
        reverse_proxy http://${config.services.navidrome.settings.Address}:${toString config.services.navidrome.settings.Port}
      '';
    };
  };
}

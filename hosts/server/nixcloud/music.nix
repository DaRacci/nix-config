{
  config,
  ...
}:
{
  server = {
    dashboard.items.music = {
      title = "Navidrome";
      icon = "sh-navidrome";
    };

    proxy.virtualHosts = {
      music = {
        public = true;
        ports = [ config.services.navidrome.settings.Port ];
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.navidrome.settings.Port}
        '';
      };
    };
  };

  services = {
    navidrome = {
      enable = true;
      settings = {
        Address = "::";
        BaseUrl = "https://music.racci.dev";
        MusicFolder = "/mnt/media/library/music";
      };
    };
  };
}

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
          reverse_proxy http://${config.services.navidrome.settings.Address}:${toString config.services.navidrome.settings.Port}
        '';
      };
    };
  };

  server.tests.units = {
    navidrome = {
      testScript = ''
        nixcloud.succeed("systemctl show navidrome.service | grep -i loadstate")
      '';
    };
    music-assistant = {
      testScript = ''
        nixcloud.succeed("systemctl show music-assistant.service | grep -i loadstate")
      '';
    };
  };

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
}

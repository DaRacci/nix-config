{
  services = {
    wyoming = {
      piper.servers.default = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = "en_GB-cori-high";
      };
      faster-whisper.servers.default = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        device = "auto";
        language = "auto";
        model = "turbo";
      };
    };
  };

  server.proxy.virtualHosts = {
    whisper = rec {
      ports = [ l4.listenPort ];
      l4 = {
        listenPort = 10300;
        config = ''
          route {
            proxy localhost:${toString l4.listenPort}
          }
        '';
      };
    };

    piper = rec {
      ports = [ l4.listenPort ];
      l4 = {
        listenPort = 10200;
        config = ''
          route {
            proxy localhost:${toString l4.listenPort}
          }
        '';
      };
    };
  };
}

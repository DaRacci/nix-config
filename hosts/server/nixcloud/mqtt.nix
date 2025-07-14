{
  config,
  ...
}:
{
  sops.secrets."MQTT_ROOT_PASSWORD" = { };

  services.mosquitto = {
    enable = true;
    logType = [ "all" ];
    listeners = [
      {
        address = "127.0.0.1";
        users.root = {
          acl = [ "readwrite #" ];
          passwordFile = config.sops.secrets."MQTT_ROOT_PASSWORD".path;
        };
      }
    ];
  };

  server.proxy.virtualHosts.mqtt = rec {
    ports = [ l4.listenPort ];
    l4 = {
      listenPort = 1883;
      config = ''
        route {
          tls
          proxy localhost:${toString l4.listenPort}
        }
      '';
    };
  };
}

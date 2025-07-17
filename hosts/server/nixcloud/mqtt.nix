{
  config,
  ...
}:
{
  sops.secrets."MQTT_ROOT_PASSWORD" = { };
  services = {
    mosquitto = {
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

    zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = true;
        mqtt.server = "mqtt://localhost:1883";
        serial.port = "/dev/ttyACM0";
        frontend.enabled = true;
      };
    };
  };

  server.proxy.virtualHosts = {
    mqtt = rec {
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

    zigbee2mqtt.extraConfig = ''
      reverse_proxy http://localhost:8080
    '';
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}

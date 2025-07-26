{
  config,
  pkgs,
  ...
}:

let
  inherit (config.sops) secrets;
in
{
  sops.secrets = {
    "MQTT_PASSWORDS/ROOT" = { };
    "MQTT_PASSWORDS/HA" = { };
    "MQTT_PASSWORDS/DEVICES" = { };
    "MQTT_PASSWORDS/SLEEPASANDROID" = { };
    # Must not be nested so that zigbee2mqtt can access it
    "MQTT_PASSWORDS_ZIGBEE2MQTT" = { };

    "ZIGBEE2MQTT_SECRETS" = {
      owner = config.users.users.zigbee2mqtt.name;
      inherit (config.users.users.zigbee2mqtt) group;
      key = "";
      path = "/var/lib/zigbee2mqtt/secrets.yaml";
      restartUnits = [ "zigbee2mqtt.service" ];
    };
  };

  services = {
    home-assistant = {
      extraComponents = [
        "matter"
        "mqtt"
        "smlight"
      ];
    };

    matter-server.enable = true;

    mosquitto = {
      enable = true;
      logType = [ "all" ];

      listeners = [
        {
          address = "0.0.0.0";

          acl = [
            # allow reading of system topics
            "topic read $SYS/#"
          ];

          users = {
            root = {
              passwordFile = secrets."MQTT_PASSWORDS/ROOT".path;
              acl = [ "readwrite #" ];
            };

            device = {
              passwordFile = secrets."MQTT_PASSWORDS/DEVICES".path;
              acl = [
                "readwrite homeassistant/+/%u/#"
                "read homeassistant/status"
                "read $SYS/#"
              ];
            };

            homeassistant = {
              passwordFile = secrets."MQTT_PASSWORDS/HA".path;
              acl = [
                "readwrite homeassistant/#"
                "read SleepAsAndroid/#"
              ];
            };

            zigbee2mqtt = {
              passwordFile = secrets."MQTT_PASSWORDS_ZIGBEE2MQTT".path;
              acl = [
                "readwrite homeassistant/#"
                "readwrite zigbee2mqtt/#"
              ];
            };

            sleepasandroid = {
              passwordFile = secrets."MQTT_PASSWORDS/SLEEPASANDROID".path;
              acl = [ "readwrite SleepAsAndroid/#" ];
            };
          };
        }
      ];
    };

    zigbee2mqtt = {
      enable = true;
      package = pkgs.zigbee2mqtt_2;
      settings = {
        homeassistant = true;
        mqtt = {
          server = "mqtt://localhost:1883";
          user = "zigbee2mqtt";
          password = "!secrets.yaml MQTT_PASSWORDS_ZIGBEE2MQTT";
        };
        serial = {
          port = "tcp://SLZB-06M:6638";
          baudrate = 115200;
          adapter = "ember";
        };
        frontend = {
          enabled = true;
          package = "zigbee2mqtt-windfront";
        };
        advanced.transmit_power = 20;
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
            proxy localhost:${toString l4.listenPort}
          }
        '';
      };
    };

    zigbee2mqtt.extraConfig = ''
      reverse_proxy http://localhost:8080
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [
      5580
      8080
    ];
    allowedUDPPorts = [ 5580 ];
  };
}

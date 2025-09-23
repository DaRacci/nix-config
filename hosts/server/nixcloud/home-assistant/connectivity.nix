{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.sops) secrets;
in
{
  sops = {
    secrets =
      [
        "ROOT"
        "HA"
        "DEVICES"
        "SLEEPASANDROID"
        "ZIGBEE2MQTT"
      ]
      |> map (
        v:
        lib.nameValuePair "MQTT_PASSWORDS/${v}" {
          restartUnits = [ "mosquitto.service" ];
        }
      )
      |> builtins.listToAttrs;

    templates.zigbee2mqtt = {
      owner = config.users.users.zigbee2mqtt.name;
      inherit (config.users.users.zigbee2mqtt) group;
      path = "/var/lib/zigbee2mqtt/secrets.yaml";
      restartUnits = [ "zigbee2mqtt.service" ];
      content = ''
        mqtt_password: ${config.sops.placeholder."MQTT_PASSWORDS/ZIGBEE2MQTT"}
      '';
    };
  };

  services = {
    home-assistant = {
      extraComponents = [
        "matter"
        "mqtt"
        "smlight"
        "esphome"
      ];
    };

    esphome = {
      enable = true;
      openFirewall = true;
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
              passwordFile = secrets."MQTT_PASSWORDS/ZIGBEE2MQTT".path;
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
        mqtt = {
          server = "mqtt://localhost:1883";
          user = "zigbee2mqtt";
          password = "!secrets.yaml mqtt_password";
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

    esphome.extraConfig = ''
      reverse_proxy http://localhost:${builtins.toString config.services.esphome.port}
    '';

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

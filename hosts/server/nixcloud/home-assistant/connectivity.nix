{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.sops) secrets;

  mqttPort = (config.services.mosquitto.listeners |> builtins.head).port;
in
{
  users = {
    groups.matterjs = {
      gid = 1500;
    };
    users.matterjs = {
      isSystemUser = true;
      uid = 1500;
      group = "matterjs";
    };
  };

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
      address = "0.0.0.0";
    };

    matterjs-server = {
      enable = true;
      listenAddress = "0.0.0.0";

      # BLE is done by the host's BlueZ over D-Bus, so no raw HCI access is needed
      # but this flag is still required: it sets PrivateUsers = false,
      # without which dbus-next's peer-UID authentication to the proxy fails.
      bluetoothSupport = true;
      extraArgs = [
        "--bluetooth-adapter=0"
        "--primary-interface=eth0"

        "--vendorid=4939"
        "--fabricid=1"
      ];
    };

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
          server = "mqtt://localhost:${(toString mqttPort)}";
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

  systemd.services.matterjs-server = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = config.users.users.matterjs.name;
      Group = config.users.users.matterjs.group;
    };
    environment = {
      HOME = "/var/lib/matterjs-server";
      NOBLE_BINDINGS = "dbus";
      DBUS_SYSTEM_BUS_ADDRESS = "unix:path=/var/lib/host-bluez/bus.sock";
    };
  };

  server = {
    dashboard.items = {
      esphome.title = "ESPHome";
      mqtt.title = "MQTT Broker";
      zigbee2mqtt.title = "Zigbee2MQTT";
    };

    proxy.virtualHosts = {
      mqtt = {
        ports = [ mqttPort ];
        l4 = {
          listenPort = mqttPort;
          protocol = "tcp";
          config = ''
            route {
              proxy localhost:${toString mqttPort}
            }
          '';
        };
      };

      esphome.extraConfig = ''
        reverse_proxy http://localhost:${toString config.services.esphome.port}
      '';

      zigbee2mqtt = {
        ports = [ 8080 ];
        extraConfig = ''
          reverse_proxy http://localhost:8080
        '';
      };

      matterjs = {
        ports = [ config.services.matterjs-server.port ];
        extraConfig = ''
          reverse_proxy http://localhost:${toString config.services.matterjs-server.port}
        '';
      };
    };
  };
}

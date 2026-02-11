{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    filterAttrs
    flatten
    getExe
    listToAttrs
    literalExpression
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionalAttrs
    splitString
    ;

  inherit (lib.types)
    anything
    attrsOf
    enum
    nullOr
    path
    str
    submodule
    ;

  cfg = config.services.metrics;

  # Creates the variables ELAPSED_{HOURS, MINUTES, SECONDS} for the systemd unit running time
  systemdUnitRunningTimeFormatted = unitName: ''
    RUNNING_TIME=$(date -d "$(systemctl show -p ExecMainStartTimestamp --value ${unitName})" +%s)
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - RUNNING_TIME))
    ELAPSED_HOURS=$((ELAPSED_TIME / 3600))
    ELAPSED_MINUTES=$(( (ELAPSED_TIME % 3600) / 60 ))
    ELAPSED_SECONDS=$((ELAPSED_TIME % 60 ))
  '';

  # Creates a variable called NIXPKGS_DATE with the ISO 8601 date of the nixpkgs used by the system
  getSystemNixPkgsDate = ''
    file="/etc/os-release"
    [[ -r $file ]] || { echo "err: not readable: $file" >&2; }
    line=$(grep -m1 '^BUILD_ID=' "$file") || { echo "err: BUILD_ID missing" >&2; }
    id=''${line#BUILD_ID=}; id=''${id#\"}; id=''${id%\"}
    [[ $id =~ ^[0-9]+\.[0-9]+\.([0-9]{8})\. ]] || { echo "err: bad BUILD_ID: $id" >&2; }
    d=''${BASH_REMATCH[1]}
    NIXPKGS_DATE="''${d:0:4}-''${d:4:2}-''${d:6:2}"
  '';

  sensors = [
    "webcam"
    "cpu_temp"
    "cpu_usage"
    "uptime"
    "memory"
    "power"
    "companion_running"
    "online_check"
    "load_avg"
    "audio_volume"
  ];

  mkStorageScript =
    deviceName: deviceCfg: sensor:
    let
      scriptName = "${deviceName}_${sensor}";
      scriptPath = pkgs.writeShellScript "${scriptName}.sh" ''
        exec ${lib.getExe pkgs.drive-stats} ${sensor} ${deviceName}
      '';
    in
    {
      name = scriptName;
      value = {
        name =
          let
            devicePretty = if deviceCfg != null && deviceCfg.name != null then deviceCfg.name else deviceName;
            sensorPretty =
              {
                temperature = "Temperature";
                used = "Used";
                avail = "Available";
                read = "Read Speed";
                write = "Write Speed";
              }
              .${sensor};
          in
          "${devicePretty} — ${sensorPretty}";

        icon =
          {
            temperature = "mdi:thermostat";
            used = "mdi:harddisk";
            avail = "mdi:harddisk-plus";
            read = "mdi:download";
            write = "mdi:upload";
          }
          .${sensor};

        type = "sensor";
        path = scriptPath;

        device_class =
          {
            temperature = "temperature";
            used = "data_size";
            avail = "data_size";
            read = "data_rate";
            write = "data_rate";
          }
          .${sensor};

        unit_of_measurement =
          {
            temperature = "°C";
            used = "gigabyte";
            avail = "gigabyte";
            read = "mb/s";
            write = "mb/s";
          }
          .${sensor};
      };
    };

  storageScripts =
    let
      storageConfigs = filterAttrs (_: config: config.sensors != { }) cfg.hacompanion.storage;
    in
    listToAttrs (
      flatten (
        mapAttrsToList (
          device: config:
          mapAttrsToList (sensor: _: mkStorageScript device config sensor) (
            filterAttrs (_: enabled: enabled) config.sensors
          )
        ) storageConfigs
      )
    );

  hacompanionConfig = {
    homeassistant = {
      device_name = config.host.name;
      host = "https://hassio.racci.dev";
    };

    companion = {
      update_interval = "15s";
      registration_file = "/var/lib/hacompanion/registration.json";
    };

    notifications = {
      push_url = "http://${config.host.name}:9175/notifications";
      listen = ":9175";
    };

    sensor =
      cfg.hacompanion.sensor
      |> filterAttrs (_: s: s.enable)
      |> mapAttrs (
        n: _s: {
          enabled = true;
          name = splitString "_" n |> builtins.map lib.mine.strings.capitalise |> concatStringsSep " ";
        }
      );

    script = lib.mapAttrs (
      name: script:
      {
        inherit (script)
          name
          icon
          type
          path
          ;
      }
      // (optionalAttrs (script.unit_of_measurement != null) {
        inherit (script) unit_of_measurement;
      })
      // (lib.optionalAttrs (script.device_class != null) { inherit (script) device_class; })
    ) (cfg.hacompanion.script // storageScripts);
  };
in
{
  options.services.metrics = {
    enable = mkEnableOption "Metrics collection service";

    upgradeStatus = {
      enable = mkEnableOption "Enable Upgrade Status service";
      uptimeKuma.enable = mkEnableOption "Enable Uptime Kuma tracking for Upgrade Status";
    };

    hacompanion = {
      enable = mkEnableOption "Enable Home Assistant Companion service";
      sensor =
        sensors
        |> map (
          name:
          nameValuePair name {
            enable = mkEnableOption "Enable the ${name} sensor";
          }
        )
        |> listToAttrs;

      test = mkOption {
        type = anything;
        default = hacompanionConfig;
        defaultText = literalExpression "hacompanionConfig";
      };

      script = mkOption {
        type = attrsOf (submodule {
          options = {
            name = mkOption {
              type = str;
              description = "The name of the script as it will appear in Home Assistant.";
            };

            icon = mkOption {
              type = str;
              description = "The icon to use for the script in Home Assistant.";
              default = "mdi:script-text-outline";
            };

            type = mkOption {
              type = enum [
                "sensor"
                "switch"
              ];
              description = "The type of the script in Home Assistant.";
              default = "sensor";
            };

            path = mkOption {
              type = path;
              description = "The path to the script to execute.";
            };

            unit_of_measurement = mkOption {
              type = nullOr str;
              description = "The unit of measurement for the script in Home Assistant.";
              default = null;
            };

            device_class = mkOption {
              type = nullOr (
                # Source https://www.home-assistant.io/integrations/sensor/#device-class
                enum [
                  "absolute_humidity"
                  "apparent_power"
                  "aqi"
                  "area"
                  "atmospheric_pressure"
                  "battery"
                  "blood_glucose_concentration"
                  "carbon_dioxide"
                  "carbon_monoxide"
                  "current"
                  "data_rate"
                  "data_size"
                  "date"
                  "distance"
                  "duration"
                  "energy"
                  "energy_distance"
                  "energy_storage"
                  "enum"
                  "frequency"
                  "gas"
                  "humidity"
                  "illuminance"
                  "irradiance"
                  "moisture"
                  "monetary"
                  "nitrogen_dioxide"
                  "nitrogen_monoxide"
                  "nitrous_oxide"
                  "ozone"
                  "ph"
                  "pm1"
                  "pm10"
                  "pm25"
                  "power"
                  "power_factor"
                  "precipitation"
                  "precipitation_intensity"
                  "pressure"
                  "reactive_energy"
                  "reactive_power"
                  "signal_strength"
                  "sound_pressure"
                  "speed"
                  "sulphur_dioxide"
                  "temperature"
                  "timestamp"
                  "volatile_organic_compounds"
                  "volatile_organic_compounds_parts"
                  "voltage"
                  "volume"
                  "volume_flow_rate"
                  "volume_storage"
                  "water"
                  "weight"
                  "wind_direction"
                  "wind_speed"
                ]
              );
              description = "The device class for the script in Home Assistant.";
              default = null;
            };
          };
        });
      };

      storage = mkOption {
        type = attrsOf (submodule {
          options = {
            name = mkOption {
              type = nullOr str;
              description = "The pretty display name for this storage device in Home Assistant.";
              default = null;
            };

            sensors = {
              temperature = mkEnableOption "Enable temperature sensor";
              used = mkEnableOption "Enable used space sensor";
              avail = mkEnableOption "Enable available space sensor";
              read = mkEnableOption "Enable read speed sensor";
              write = mkEnableOption "Enable write speed sensor";
            };
          };
        });
        description = "Storage devices and ZFS pools to monitor";
        default = { };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.hacompanion.enable {
      sops.secrets.HACOMPANION_ENV = {
        sopsFile = "${self}/hosts/secrets.yaml";
      };

      systemd.services.hacompanion = {
        description = "Hacompanion for monitor system metrics";

        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];

        path = with pkgs; [
          hacompanion
          systemd
          lm_sensors-perlless
          nix
          gawk
          smartmontools
          util-linux
          zfs
          toybox
        ];

        serviceConfig =
          let
            hacompanionToml = pkgs.writers.writeTOML "hacompanion.toml" hacompanionConfig;
          in
          {
            Type = "simple";
            DynamicUser = true;
            SupplementaryGroups = [ "systemd-journal" ];
            ExecStart = "${lib.getExe pkgs.hacompanion} -quiet -config ${hacompanionToml}";
            Restart = "always";
            RestartSec = 10;
            EnvironmentFile = config.sops.secrets.HACOMPANION_ENV.path;
            StateDirectory = "hacompanion";
            WorkingDirectory = "/var/lib/hacompanion";
            BindReadOnlyPaths = [
              hacompanionToml
              "/nix/var/nix/profiles/system"
            ];
          };
      };

    })

    (mkIf cfg.upgradeStatus.enable {
      services.metrics.hacompanion.script.upgrade_status = {
        name = "NixOS Upgrade Status";
        icon = "mdi:update";
        type = "sensor";
        device_class = "timestamp";
        path = getExe (
          pkgs.writeShellApplication {
            name = "upgrade-status";
            runtimeInputs = with pkgs; [
              gnugrep
              gawk
              systemd
              toybox
            ];
            text = ''
              ${getSystemNixPkgsDate}
              LAST_PROFILE_TIMESTAMP=$(date -d "$(stat /run/current-system/nixos-version --format "%z")" +"%Y-%m-%dT%H:%M:%S%z")

              echo "$LAST_PROFILE_TIMESTAMP"
              echo "nixpkgs_date:$NIXPKGS_DATE"
              echo "last_profile_timestamp:$LAST_PROFILE_TIMESTAMP"

              # If we are on a dirty rev then don't bother with the service status.
              HAS_SERVICE=$(systemctl list-units --type=service --all | grep -c 'nixos-upgrade.service' || true)
              if [[ "$HAS_SERVICE" -ne 0 ]]; then
                STATUS=$(systemctl is-failed nixos-upgrade.service || true)
                IS_RUNNING=$(systemctl is-active nixos-upgrade.service || true)

                if [ "$IS_RUNNING" = "active" ] || [ "$STATUS" = "activating" ]; then
                  echo "status:upgrading"
                  ${systemdUnitRunningTimeFormatted "nixos-upgrade.service"}
                  echo "elapsed:''${ELAPSED_HOURS}h ''${ELAPSED_MINUTES}m ''${ELAPSED_SECONDS}s"
                elif [ "$STATUS" = "failed" ]; then
                  echo "status:failed"
                  echo "icon:mdi:alert"
                  LOG=$(journalctl -u nixos-upgrade --lines=10 --no-pager --output cat | tr '\n' ' ')
                  echo "log:\"$LOG\""
                else
                  echo "status:idle"
                fi
              else
                echo "status:dirty"
              fi
            '';
          }
        );
      };
    })

    (mkIf cfg.upgradeStatus.uptimeKuma.enable {
      sops.secrets.UPGRADE_STATUS_ID = { };

      systemd = {
        timers.upgrade-status = mkIf (self ? rev) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            Persistent = true;
            OnActiveSec = "15min";
            Unit = "upgrade-status.service";
          };
        };

        services.upgrade-status = mkIf (self ? rev) {
          wantedBy = [ "multi-user.target" ];
          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];

          environment = {
            UPTIME_ENDPOINT = "https://uptime.racci.dev/api/push";
            UNIQUE_ID_FILE = config.sops.secrets.UPGRADE_STATUS_ID.path;
          };

          serviceConfig.ExecStart = getExe (
            pkgs.writeShellApplication {
              name = "upgrade-status";
              runtimeInputs = with pkgs; [
                curl
                perl
                perlPackages.URIEscapeXS
                systemd
                gawk
                nix
              ];
              text = ''
                export PERL5LIB="${pkgs.perlPackages.URIEscapeXS}/lib/perl5/site_perl"

                URL="$UPTIME_ENDPOINT/$(cat "$UNIQUE_ID_FILE")"
                STATUS=$(systemctl is-failed nixos-upgrade.service || true)
                IS_RUNNING=$(systemctl is-active nixos-upgrade.service || true)

                function url_encode() {
                  perl -MURI::Escape::XS -e 'print encodeURIComponent($ARGV[0]);' "$1"
                }

                if [ "$IS_RUNNING" = "active" ]; then
                  echo "NixOS upgrade is currently running."
                  ${systemdUnitRunningTimeFormatted "nixos-upgrade.service"}
                  MSG="elapsed time: "
                  if [ "$ELAPSED_HOURS" -gt 0 ]; then
                    MSG="''${MSG}''${ELAPSED_HOURS}h "
                  fi
                  if [ "$ELAPSED_MINUTES" -gt 0 ]; then
                    MSG="''${MSG}''${ELAPSED_MINUTES}m "
                  fi
                  MSG="Upgrade in progress, ''${MSG}''${ELAPSED_SECONDS}s"
                  echo "$MSG"
                  MSG=$(url_encode "$MSG")
                  URL="$URL?status=up&msg=$MSG&ping="
                elif [ "$STATUS" = "failed" ]; then
                  echo "NixOS upgrade has failed."
                  LOG=$(url_encode "$(journalctl -u nixos-upgrade --lines=10 --no-pager --output cat)")
                  URL="$URL?status=down&msg=$LOG&ping="
                else
                  LAST_PROFILE_DATE=$(nix profile history --profile /nix/var/nix/profiles/system | grep '^Version' | awk -F'[()]+' '{print $2}' | tail -n 1)
                  MSG=$(url_encode "Last upgrade: $LAST_PROFILE_DATE")
                  echo "Last upgrade: $LAST_PROFILE_DATE"
                  echo "Encoded message: $MSG"
                  URL="$URL?status=up&msg=$MSG&ping="
                fi

                echo "Sending request to $URL"
                curl -s "$URL"
              '';
            }
          );
        };
      };
    })
  ];
}

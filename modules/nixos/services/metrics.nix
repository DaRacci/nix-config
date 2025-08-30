{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
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
      |> lib.filterAttrs (_: s: s.enable)
      |> lib.mapAttrs (
        n: s: {
          enabled = true;
          name =
            lib.splitString "_" n
            |> lib.map (
              n:
              let
                chars = lib.strings.stringToCharacters n;
                firstChar = lib.head chars;
                remainingChars = lib.tail chars;
              in
              builtins.concatStringsSep "" ([ (lib.toUpper firstChar) ] ++ remainingChars)
            )
            |> lib.concatStringsSep " ";
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
      // (lib.optionalAttrs (script.unit_of_measurement != null) {
        inherit (script) unit_of_measurement;
      })
      // (lib.optionalAttrs (script.device_class != null) { inherit (script) device_class; })
    ) cfg.hacompanion.script;
  };
in
{
  options.services.metrics = {
    enable = lib.mkEnableOption "Metrics collection service";

    upgradeStatus.enable = lib.mkEnableOption "Enable Upgrade Status service";

    hacompanion = {
      enable = lib.mkEnableOption "Enable Home Assistant Companion service";
      sensor =
        sensors
        |> map (
          name:
          lib.nameValuePair name {
            enable = (lib.mkEnableOption "Enable the ${name} sensor");
          }
        )
        |> lib.listToAttrs;

      test = lib.mkOption {
        type = lib.types.anything;
        default = hacompanionConfig;
      };

      script = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "The name of the script as it will appear in Home Assistant.";
              };

              icon = lib.mkOption {
                type = lib.types.str;
                description = "The icon to use for the script in Home Assistant.";
                default = "mdi:script-text-outline";
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "sensor"
                  "switch"
                ];
                description = "The type of the script in Home Assistant.";
                default = "sensor";
              };

              path = lib.mkOption {
                type = lib.types.path;
                description = "The path to the script to execute.";
              };

              unit_of_measurement = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                description = "The unit of measurement for the script in Home Assistant.";
                default = null;
              };

              device_class = lib.mkOption {
                type = lib.types.nullOr (
                  # Source https://www.home-assistant.io/integrations/sensor/#device-class
                  lib.types.enum [
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
          }
        );
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.hacompanion.enable {
        sops.secrets.HACOMPANION_ENV = {
          sopsFile = "${self}/hosts/secrets.yaml";
        };

        systemd.services.hacompanion = {
          description = "Hacompanion for monitor system metrics";

          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ] ++ (lib.optionals (self ? rev) [ "nixos-upgrade.service" ]);
          requires = [ "network-online.target" ];

          path = with pkgs; [
            hacompanion
            lm_sensors
            systemd
            nix
            gawk
          ];

          serviceConfig =
            let
              hacompanionToml = pkgs.writers.writeTOML "hacompanion.toml" hacompanionConfig;
            in
            {
              Type = "simple";
              DynamicUser = true;
              ExecStart = "${lib.getExe pkgs.hacompanion} -quiet -config ${hacompanionToml}";
              Restart = "on-failure";
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

      (lib.mkIf cfg.upgradeStatus.enable {
        sops.secrets.UPGRADE_STATUS_ID = { };

        services.metrics.hacompanion.script.upgrade_status = {
          name = "NixOS Upgrade Status";
          icon = "mdi:update";
          type = "sensor";
          device_class = "timestamp";
          path = lib.getExe (
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
                    LOG=$(journalctl -u nixos-upgrade --lines=10 --no-pager --output cat)
                    echo "log:$LOG"
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

        systemd = {
          timers.upgrade-status = lib.mkIf (self ? rev) {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              Persistent = true;
              OnUnitInactiveSec = "15min";
              Unit = "upgrade-status.service";
            };
          };

          services.upgrade-status = lib.mkIf (self ? rev) {
            wantedBy = [ "multi-user.target" ];
            requires = [ "network-online.target" ];
            after = [
              "network-online.target"
              "nixos-upgrade.service"
            ];

            environment = {
              UPTIME_ENDPOINT = "https://uptime.racci.dev/api/push";
              UNIQUE_ID_FILE = config.sops.secrets.UPGRADE_STATUS_ID.path;
            };

            serviceConfig.ExecStart = lib.getExe (
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
    ]
  );
}

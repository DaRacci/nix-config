{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  # Creates the variabels ELAPSED_{HOURS, MINUTES, SECONDS} for the systemd unit running time
  systemdUnitRunningTimeFormatted = unitName: ''
    RUNNING_TIME=$(systemctl show -p ActiveEnterTimestamp --value ${unitName})
    RUNNING_TIME=$(date -d "$RUNNING_TIME" +%s)
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - RUNNING_TIME))
    ELAPSED_HOURS=$((ELAPSED_TIME / 3600))
    ELAPSED_MINUTES=$(( (ELAPSED_TIME % 3600) / 60 ))
    ELAPSED_SECONDS=$((ELAPSED_TIME % 60 ))
  '';

  hacompanionToml = pkgs.writers.writeTOML "hacompanion.toml" {
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

    sensor = {
      webcam.enabled = false;
      cpu_temp.enabled = false;
      cpu_usage.enabled = true;
      uptime.enabled = true;
      memory.enabled = true;
      power.enabled = false;
      companion_running.enabled = true;
      online_check.enabled = false;
      load_avg.enabled = true;
      audio_volume.enabled = false;
    };

    script = {
      upgrade_status = {
        name = "NixOS Upgrade Status";
        icon = "mdi:update";
        type = "sensor";
        unit_of_measurement = "";
        device_class = "";
        path = pkgs.writeShellScript "upgrade-status" ''
          STATUS=$(systemctl is-failed nixos-upgrade.service || true)
          IS_RUNNING=$(systemctl is-active nixos-upgrade.service || true)
          LAST_PROFILE_DATE=$(nix profile history --profile /nix/var/nix/profiles/system | grep '^Version' | awk -F'[()]+' '{print $2}' | tail -n 1)

          if [ "$IS_RUNNING" = "active" ]; then
            echo "Upgrading"
            ${systemdUnitRunningTimeFormatted "nixos-upgrade.service"}
            echo "elapsed:''${ELAPSED_HOURS}h ''${ELAPSED_MINUTES}m ''${ELAPSED_SECONDS}s"
          elif [ "$STATUS" = "failed" ]; then
            echo "Upgrade failed"
            LOG=$(journalctl -u nixos-upgrade --lines=10 --no-pager --output cat)
            echo "log:$LOG"
          else
            echo "Last upgrade: $LAST_PROFILE_DATE"
          fi
        '';
      };
    };
  };
in
{
  sops.secrets = {
    UPGRADE_STATUS_ID = { };
    HACOMPANION_ENV = { };
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

    services = {
      upgrade-status = lib.mkIf (self ? rev) {
        wantedBy = [ "multi-user.target" ];
        requires = [ "network-online.target" ];
        after = [ "network-online.target" ];

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

      # TODO - Harden
      hacompanion = {
        description = "Hacompanion for monitor system metrics";

        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];

        path = with pkgs; [
          hacompanion
          lm_sensors
        ];

        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          ExecStart = "${lib.getExe pkgs.hacompanion} -config ${hacompanionToml}";
          Restart = "on-failure";
          EnvironmentFile = config.sops.secrets.HACOMPANION_ENV.path;
          StateDirectory = "hacompanion";
          WorkingDirectory = "/var/lib/hacompanion";
          BindReadOnlyPaths = [ hacompanionToml ];
        };
      };
    };
  };
}

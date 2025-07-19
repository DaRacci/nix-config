{
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets."UPGRADE_STATUS_ID" = { };

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
              RUNNING_TIME=$(systemctl show -p ActiveEnterTimestamp --value nixos-upgrade.service)
              RUNNING_TIME=$(date -d "$RUNNING_TIME" +%s)
              CURRENT_TIME=$(date +%s)
              ELAPSED_TIME=$((CURRENT_TIME - RUNNING_TIME))
              ELAPSED_HOURS=$((ELAPSED_TIME / 3600))
              ELAPSED_MINUTES=$(( (ELAPSED_TIME % 3600) / 60 ))
              ELAPSED_SECONDS=$((ELAPSED_TIME % 60 ))
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
}

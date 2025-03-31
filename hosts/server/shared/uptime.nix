{
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets."UPGRADE_STATUS_ID" = { };

  systemd = {
    timers.upgrade-status = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Persistent = true;
        OnUnitInactiveSec = "15min";
        Unit = "upgrade-status.service";
      };
    };

    services.upgrade-status = {
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

            function url_encode() {
              perl -MURI::Escape::XS -e 'print encodeURIComponent($ARGV[0]);' "$1"
            }

            if [ "$STATUS" = "failed" ]; then
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

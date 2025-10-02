{
  self,
  config,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets.TAILSCALE_AUTH_KEY = {
    sopsFile = "${self}/hosts/secrets.yaml";
    restartUnits = [
      "tailscaled-autoconnect.service"
      "tailscaled.service"
    ];
  };

  services.tailscale = {
    enable = true;
    package = pkgs.tailscale;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets.TAILSCALE_AUTH_KEY.path;
    extraDaemonFlags = [ "--no-logs-no-support" ];
    extraUpFlags = [
      "--accept-dns=true"
      "--accept-routes"
    ];
    tags = [
      "nixos"
      config.host.device.role
    ]
    ++ config.host.device.purpose
    ++ (lib.optional config.host.device.isVirtual "virtual")
    ++ (lib.optional config.host.device.isHeadless "headless");
  };

  systemd.services.tailscale-check = {
    description = "Check Tailscale login status";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "tailscale-check";
          runtimeInputs = [
            pkgs.tailscale
            pkgs.systemd
            pkgs.jq
          ];
          text = ''
            STATE=$(tailscale status --json --peers=false | jq -r .BackendState)
            if [ "$STATE" == "NeedsLogin" ]; then
              echo "Tailscale is not logged in. Running tailscaled-autoconnect service."
              systemctl start tailscaled-autoconnect.service
            else
              echo "Tailscale is logged in."
            fi
          '';
        }
      );
    };
  };

  systemd.timers.tailscale-check = {
    description = "Periodically check Tailscale login status";
    wantedBy = [ "timers.target" ];
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    timerConfig = {
      OnStartupSec = "30s";
      OnUnitActiveSec = "20m";
      Persistent = true;
    };
  };

  host.persistence.directories = [ "/var/lib/tailscale" ];
}

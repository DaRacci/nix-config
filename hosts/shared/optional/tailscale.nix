{
  self,
  config,
  pkgs,
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
  };

  systemd.services.tailscale-check = {
    description = "Check Tailscale login status";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    script = ''
      set -e
      if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
        echo "Tailscale is not logged in. Running tailscaled-autoconnect service."
        systemctl start tailscaled-autoconnect.service
      else
        echo "Tailscale is logged in."
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
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

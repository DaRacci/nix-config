{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe'
    optional
    mkIf
    mkEnableOption
    ;
  cfg = config.core.networking.tailscale;
in
{
  options.core.networking.tailscale.enable = mkEnableOption "tailscale configuration";

  config = mkIf cfg.enable {
    sops.secrets.TAILSCALE_AUTH_KEY = {
      sopsFile = "${self}/hosts/secrets.yaml";
      restartUnits = [
        "tailscaled-autoconnect.service"
        "tailscaled.service"
      ];
    };

    services.tailscale = {
      enable = true;
      disableUpstreamLogging = true;
      disableTaildrop = true;
      useRoutingFeatures = "client";

      authKeyFile = config.sops.secrets.TAILSCALE_AUTH_KEY.path;
      authKeyParameters.preauthorized = true;

      extraUpFlags = [
        "--accept-dns=true"
        "--accept-routes=true"
      ];

      tags = [
        "nixos"
        config.host.device.role
      ]
      ++ config.host.device.purpose
      ++ (optional config.host.device.isVirtual "virtual")
      ++ (optional config.host.device.isHeadless "headless");
    };

    systemd = {
      services.tailscale-check = {
        description = "Check Tailscale login status";
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStart = "${getExe' pkgs.systemd "systemctl"} start tailscaled-autoconnect.service";
        };
      };

      timers.tailscale-check = {
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
    };

    host.persistence.directories = [ "/var/lib/tailscale" ];
  };
}

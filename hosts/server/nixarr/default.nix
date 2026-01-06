{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.nixarr.nixosModules.default
    ./arr
  ];

  # wg service fails to start on boot due to network not being ready
  # The upstream VPN-Confinement module only retries 5 times with 1s delays,
  # which is too short during early boot. Adding restart settings ensures
  # the service will eventually succeed once networking is available.
  systemd.services.wg.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "10s";
  };

  users.users.jellyfin.extraGroups = [ "video" ];

  sops.secrets.wireguard = {
    format = "binary";
    sopsFile = ./wg.conf;
  };

  vpnNamespaces.wg.accessibleFrom = lib.mkForce [
    "192.168.0.0/16"
    "100.100.0.0/16"
    "127.0.0.1"
  ];

  hardware.graphics = {
    enable = true;
  };

  nixarr = {
    enable = true;

    vpn = {
      enable = true;
      vpnTestService.enable = true;
      wgConf = config.sops.secrets.wireguard.path;
    };

    jellyfin.enable = true;
    jellyseerr.enable = true;
  };

  server = {
    dashboard.icon = "sh-mediamanager";

    proxy.virtualHosts = {
      jellyfin = {
        public = true;
        extraConfig = ''
          reverse_proxy localhost:8096
        '';
      };
      jellyseerr = {
        public = true;
        extraConfig = ''
          reverse_proxy localhost:${toString config.nixarr.jellyseerr.port}
        '';
      };
    };
  };
}

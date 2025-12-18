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

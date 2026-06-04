{
  config,
  lib,
  ...
}:
{
  nixarr = {
    transmission = {
      enable = true;
      vpn.enable = true;
      flood.enable = true;
      peerPort = 51413;
      extraAllowedIps = [ "100.100.0.0/16" ];

      privateTrackers.cross-seed = {
        enable = true;
        indexIds = [
          2
          5
          7
          10
          11
          12
          15
          17
          22
          24
          27
          29
        ];

        extraSettings = {
          excludeRecentSearch = "90 days";
          excludeOlder = "270 days";
        };
      };

      extraSettings = {
        rpc-host-whitelist-enabled = true;
        rpc-host-whitelist = "transmission.racci.dev";

        upload_limit = 4096;
        upload_limit_enabled = true;

        ratio_limit = 2;
        ratio_limit_enabled = true;
      };
    };

    sabnzbd = {
      enable = true;
      vpn.enable = true;
      whitelistRanges = [ "100.100.0.0/16" ];
      whitelistHostnames = [ "sabnzbd.racci.dev" ];
    };
  };

  services = {
    transmission.openPeerPorts = lib.mkForce true;
    #TODO:https://github.com/nix-media-server/nixarr/pull/132
    sabnzbd.allowConfigWrite = true;
  };

  systemd.services.transmission = {
    after = [ "wg.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      StartLimitIntervalSec = 90;
      StartLimitBurst = 3;
    };
  };

  server.proxy.virtualHosts = {
    transmission.extraConfig = ''
      reverse_proxy localhost:${toString config.nixarr.transmission.uiPort}
    '';
    sabnzbd.extraConfig = ''
      reverse_proxy localhost:${toString config.nixarr.sabnzbd.guiPort}
    '';
  };
}

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

        speed-limit-up-enabled = true;
        speed-limit-up = 8192;
      };
    };

    sabnzbd = {
      enable = true;
      vpn.enable = true;
      whitelistHostnames = [ "sabnzbd.racci.dev" ];
    };
  };

  services.transmission.openPeerPorts = lib.mkForce true;

  server.proxy.virtualHosts.transmission.extraConfig = ''
    reverse_proxy localhost:${toString config.nixarr.transmission.uiPort}
  '';
}

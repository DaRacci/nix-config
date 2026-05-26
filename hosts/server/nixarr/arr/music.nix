{
  config,
  pkgs,
  ...
}:
{
  nixarr.lidarr = {
    enable = true;
    package = pkgs.lidarr-plugins;
    vpn.enable = true;
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      public = {
        browseable = "yes";
        comment = "Public Music Share";
        "guest ok" = "yes";
        path = "/data/media/library/music";
        "read only" = "yes";
      };
    };
  };

  systemd.services.lidarr = {
    after = [ "wg.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      StartLimitIntervalSec = 90;
      StartLimitBurst = 3;
    };
  };

  server.proxy.virtualHosts.lidarr.extraConfig = ''
    reverse_proxy localhost:${toString config.nixarr.lidarr.port}
  '';

}

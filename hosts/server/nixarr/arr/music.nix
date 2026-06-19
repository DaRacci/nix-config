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
    path = [
      pkgs.nodejs-slim # Required for Tuberify YT Token Refresh
    ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      StartLimitIntervalSec = 90;
      StartLimitBurst = 3;
    };
  };

  server.proxy.virtualHosts.lidarr = {
    ports = [ config.nixarr.lidarr.port ];
    extraConfig = ''
      reverse_proxy localhost:${toString config.nixarr.lidarr.port}
    '';
  };

}

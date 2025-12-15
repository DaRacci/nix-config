{
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

  server.proxy.virtualHosts.lidarr.extraConfig = ''
    reverse_proxy localhost:8686
  '';

}

{
  nixarr.prowlarr = {
    enable = true;
    vpn.enable = true;
  };

  systemd.services.prowlarr = {
    after = [ "wg.service" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
      StartLimitIntervalSec = 90;
      StartLimitBurst = 3;
    };
  };

  server.proxy.virtualHosts.prowlarr.extraConfig = ''
    reverse_proxy localhost:9696
  '';
}

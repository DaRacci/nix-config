{
  nixarr.prowlarr = {
    enable = true;
    vpn.enable = true;
  };

  server.proxy.virtualHosts.prowlarr.extraConfig = ''
    reverse_proxy localhost:9696
  '';
}

{
  nixarr.readarr = {
    enable = true;
    vpn.enable = true;
  };

  server.proxy.virtualHosts.readarr.extraConfig = ''
    reverse_proxy localhost:8787
  '';

}

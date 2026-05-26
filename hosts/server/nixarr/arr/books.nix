{
  config,
  ...
}:
{
  nixarr.shelfmark = {
    enable = true;
    vpn.enable = true;
  };

  server.proxy.virtualHosts.readarr.extraConfig = ''
    reverse_proxy localhost:${toString config.nixarr.shelfmark.port}
  '';
}

{
  config,
  ...
}:
{
  nixarr.shelfmark = {
    enable = true;
    vpn.enable = true;
  };

  server.proxy.virtualHosts.readarr = {
    ports = [ config.nixarr.shelfmark.port ];
    extraConfig = ''
      reverse_proxy localhost:${toString config.nixarr.shelfmark.port}
    '';
  };
}

{
  config,
  ...
}:
{
  nixarr.bazarr = {
    enable = true;
    # Broken atm
    # vpn.enable = true;
  };

  server.proxy.virtualHosts.bazarr.extraConfig = ''
    reverse_proxy localhost:${toString config.nixarr.bazarr.port}
  '';
}

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

  server.proxy.virtualHosts.bazarr = {
    ports = [ config.nixarr.bazarr.port ];
    extraConfig = ''
      reverse_proxy localhost:${toString config.nixarr.bazarr.port}
    '';
  };
}

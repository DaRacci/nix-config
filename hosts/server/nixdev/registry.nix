{
  config,
  ...
}:
let
  cfg = config.services.dockerRegistry;
in
{
  server.proxy.virtualHosts.registry = {
    public = true;
    ports = [ cfg.port ];
    extraConfig = ''
      reverse_proxy http://localhost:${toString cfg.port}
    '';
  };

  services.dockerRegistry = {
    enable = true;
    enableDelete = true;
  };
}

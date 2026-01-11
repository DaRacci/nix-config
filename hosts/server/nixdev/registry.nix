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

  # TODO - Move storage to minio bucket
  services.dockerRegistry = {
    enable = true;
    enableDelete = true;
  };

  systemd.services.docker-registry.environment = {
    OTEL_TRACES_EXPORTER = "none";
  };
}

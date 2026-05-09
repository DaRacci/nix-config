{
  importModule,
  ...
}:
{
  ...
}:
{
  imports = [
    (importModule ./prometheus.nix { })
    (importModule ./loki.nix { })
    (importModule ./grafana.nix { })
    (importModule ./otlp.nix { })
    (importModule ./alerting.nix { })
    (importModule ./dashboards.nix { })
  ];
}

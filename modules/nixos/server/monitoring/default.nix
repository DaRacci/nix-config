{
  importModule,
  ...
}:
{
  ...
}:
{
  imports = [
    (importModule ./options.nix { })
    (importModule ./collector { })
    (importModule ./exporters { })
    (importModule ./logs/promtail.nix { })
    (importModule ./integrations/proxmox.nix { })
  ];
}

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
    (importModule ./logs/alloy.nix { })
    (importModule ./integrations/proxmox.nix { })
  ];
}

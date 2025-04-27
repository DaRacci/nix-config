{
  flake,
  config,
  lib,
  ...
}:
let
  isNixio = config.host.name == "nixio";
  nixioConfig = flake.nixosConfigurations.nixio.config;
  getNixioConfig =
    attrPath:
    let
      configuration = if isNixio then config else nixioConfig;
      attrs = lib.splitString "." attrPath;
    in
    lib.lists.foldl' (acc: attr: acc.${attr}) configuration attrs;

  importModule = path: import path { inherit isNixio nixioConfig getNixioConfig; };
in
{
  imports = [
    (importModule ./database.nix)
    (importModule ./proxy.nix)
  ];
}

{
  isNixio,
  importModule,
  ...
}:
{
  self,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  serverConfigurations = lib.trivial.pipe self.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (cfg: cfg.host.device.role == "server"))
    (builtins.filter (cfg: cfg.server.database ? postgres && cfg.server.database.postgres != { }))
  ];

  gatherOtherInstances =
    attrPath:
    serverConfigurations
    |> builtins.filter (cfg: cfg.host.name != "nixio")
    |> builtins.map (cfg: lib.attrsets.attrByPath (lib.splitString "." attrPath) null cfg)
    |> builtins.filter (
      item:
      if lib.isList item then
        item != [ ]
      else if lib.isAttrs item then
        item != { }
      else
        item != null
    );

  gatherAllInstances =
    attrPath:
    serverConfigurations
    |> builtins.map (cfg: lib.attrsets.attrByPath (lib.splitString "." attrPath) null cfg)
    |> builtins.filter (
      item:
      if lib.isList item then
        item != [ ]
      else if lib.isAttrs item then
        item != { }
      else
        item != null
    );
in
{
  imports = [
    (importModule ./postgres.nix {
      inherit
        serverConfigurations
        gatherOtherInstances
        gatherAllInstances
        ;
    })
    (importModule ./redis.nix {
      inherit
        serverConfigurations
        gatherOtherInstances
        gatherAllInstances
        ;
    })
  ];

  options.server.database = {
    host = mkOption {
      type = types.str;
      default = if isNixio then "localhost" else "nixio";
      readOnly = true;
      description = ''
        The hostname or IP address to use when connecting to managed databases.

        This is "localhost" when running on the host,
        and <value> when connecting from other hosts.
      '';
    };
  };
}

{
  isThisIOPrimaryHost,
  importModule,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (types) str;
in
{
  imports = [
    (importModule ./postgres.nix { })
    (importModule ./redis.nix { })
    (importModule ./guardian.nix { })
  ];

  options.server.database = {
    host = mkOption {
      type = str;
      default = if isThisIOPrimaryHost then "localhost" else config.server.ioPrimaryHost;
      readOnly = true;
      description = ''
        The hostname or IP address to use when connecting to managed databases.

        This is "localhost" when running on the host,
        and <value> when connecting from other hosts.
      '';
    };
  };
}

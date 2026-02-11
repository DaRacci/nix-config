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
  inherit (lib) types mkIf mkOption;
  inherit (types) str nullOr;

  cfg = config.server.database;
in
{
  imports = [
    (importModule ./postgres.nix { })
    (importModule ./redis.nix { })
    (importModule ./guardian.nix { })
  ];

  options.server.database = {
    host = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        The hostname or IP address to use when connecting to managed databases.

        This is "localhost" when running on the host,
        and <value> when connecting from other hosts.
      '';
    };
  };

  config = mkIf config.server.enable {
      assertions = [
        {
          assertion = cfg.host != null;
          message = "The database host must be specified.";
        }
      ];

      server.database.host = if isThisIOPrimaryHost then "localhost" else config.server.ioPrimaryHost;
    };
}

{
  isThisIOPrimaryHost,
  importModule,
  ...
}:
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkOption
    literalExpression
    ;
  inherit (types) str;

  cfg = config.server.database;

  clusterDomain = self.data.network.cluster.domain;
  ioHostAddress =
    if isThisIOPrimaryHost then "localhost" else "${config.server.ioPrimaryHost}.${clusterDomain}";
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
      default = ioHostAddress;
      defaultText = literalExpression ''
        if isThisIOPrimaryHost then "localhost" else "''${config.server.ioPrimaryHost}.''${clusterDomain}"
      '';
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
  };
}

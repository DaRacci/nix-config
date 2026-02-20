{
  isThisIOPrimaryHost,
  collectAllAttrs,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;

  hasPostgresDatabases =
    (collectAllAttrs "server.database.postgres" |> builtins.attrNames |> builtins.length) > 0;
in
{
  config =
    mkIf (cfg.enable && cfg.exporters.postgres.enable && isThisIOPrimaryHost && hasPostgresDatabases)
      {
        services.prometheus.exporters.postgres = {
          enable = true;
          port = 9187;
          listenAddress = "0.0.0.0";

          runAsLocalSuperUser = true;
        };

        networking.firewall.allowedTCPPorts = [ 9187 ];
      };
}

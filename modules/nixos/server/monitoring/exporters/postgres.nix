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
  inherit (lib) mkIf mkAfter;

  cfg = config.server.monitoring;

  hasPostgresDatabases =
    (collectAllAttrs "server.database.postgres" |> builtins.attrNames |> builtins.length) > 0;
in
{
  config =
    mkIf (cfg.enable && cfg.exporters.postgres.enable && isThisIOPrimaryHost && hasPostgresDatabases)
      {
        services = {
          prometheus.exporters.postgres = {
            enable = true;
          };

          postgresql = {
            ensureUsers.postgres-exporter = { };
          };
        };

        systemd.services.postgresql-setup.postStart = mkAfter ''
          GRANT pg_monitor to postgres_exporter;
        '';

        server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.postgres.port ];
      };
}

{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf toShellVars;

  cfg = config.services.atuin;
in
{
  config = mkIf cfg.enable {
    sops.templates.ATUIN_ENV = {
      restartUnits = [ "atuin.service" ];

      content =
        let
          db = config.server.database.postgres.atuin;
        in
        toShellVars {
          ATUIN_DB_URI = "postgresql://${db.user}:${
            config.sops.placeholder."POSTGRES/ATUIN_PASSWORD"
          }@${db.host}:${toString db.port}/${db.database}?sslmode=disable";
        };
    };

    server = {
      database.postgres.atuin = { };

      proxy.virtualHosts.atuin = {
        public = true;
        ports = [ cfg.port ];
        extraConfig = ''
          reverse_proxy http://localhost:${toString cfg.port}
        '';
      };
    };

    services.atuin = {
      host = "0.0.0.0";
      openRegistration = true;

      database = {
        createLocally = false;
        uri = null;
      };

      environmentFile = config.sops.templates.ATUIN_ENV.path;
    };
  };
}

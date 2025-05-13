{
  config,
  ...
}:
{
  services.keycloak = {
    enable = true;

    settings = {
      http-host = "0.0.0.0";
      http-port = 8080;
      hostname = "keycloak.racci.dev";

      proxy-protocol-enabled = true;
      proxy-trusted-addresses = [
        "192.168.1.0/24"
        "192.168.2.0/24"
        "100.0.0.0/8"
      ];
    };

    database =
      let
        db = config.server.database.postgres.keycloak;
      in
      {
        createLocally = false;
        type = "postgresql";
        inherit (db) host port;
        username = db.user;
        name = db.database;
        passwordFile = db.password.path;
      };
  };

  server = {
    database.postgres.keycloak = { };

    proxy.virtualHosts.keycloak.extraConfig =
      let
        cfg = config.services.keycloak.settings;
      in
      ''
        reverse_proxy http://${cfg.http-host}:${cfg.http-port}
      '';
  };
}

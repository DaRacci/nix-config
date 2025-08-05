{
  config,
  ...
}:
{
  sops.secrets.CODER_ENV = {
    owner = config.users.users.coder.name;
    inherit (config.users.users.coder) group;
  };

  users.extraUsers.coder = {
    extraGroups = [ "docker" ];
  };

  server = {
    database.postgres.coder = {
      password = {
        owner = config.users.users.coder.name;
        inherit (config.users.users.coder) group;
      };
    };

    proxy.virtualHosts.coder.extraConfig = ''
      reverse_proxy http://${config.services.coder.listenAddress}
    '';
  };

  services.coder = {
    enable = true;
    accessUrl = "https://coder.racci.dev";
    listenAddress = "0.0.0.0:8080";

    environment.file = config.sops.secrets.CODER_ENV.path;

    database =
      let
        db = config.server.database.postgres.coder;
      in
      {
        createLocally = false;
        inherit (db) host database;
        username = db.user;

        # This comes from the environment file
        password = "\${CODER_PASSWORD}";
      };
  };
}

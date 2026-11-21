{
  config,
  ...
}:
{
  sops.secrets.MNEMOSYNE_SYNC_KEY = {
    restartUnits = [
      "mnemosyne-sync-server.service"
      "mnemosyne-sync-client-hermes.service"
    ];
  };

  server.proxy.virtualHosts."mnemosyne.racci.dev" = {
    ports = [ config.services.mnemosyne.server.sync.port ];
    extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.mnemosyne.server.sync.port}
    '';
  };

  services.mnemosyne = {
    enable = true;

    server = {
      sync = {
        enable = true;
        host = "::";
        port = 8765;
        apiKeyFile = config.sops.secrets.MNEMOSYNE_SYNC_KEY.path;
      };
    };
  };
}

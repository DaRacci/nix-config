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
      reverse_proxy ${config.services.mnemosyne.server.sync.host}:${config.services.mnemosyne.server.sync.port}
    '';
  };

  services.mnemosyne = {
    enable = true;

    server = {
      sync = {
        enable = true;
        host = "127.0.0.1";
        port = 8765;
        apiKeyFile = config.sops.secrets.MNEMOSYNE_SYNC_KEY.path;
      };
    };

    client.sync.hermes = {
      remote = "http://127.0.0.1:8765";
      interval = "*:0/10";
      container = "hermes-agent";
      user = "hermes";
      apiKeyFile = config.sops.secrets.MNEMOSYNE_SYNC_KEY.path;
    };
  };
}

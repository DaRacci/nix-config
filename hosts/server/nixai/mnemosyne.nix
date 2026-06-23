_: {
  services.mnemosyne = {
    enable = true;

    syncServer = {
      enable = true;
      host = "127.0.0.1";
      port = 8765;
    };

    mcpServer = {
      enable = false;
      host = "127.0.0.1";
      port = 8766;
    };

    syncClients.hermes = {
      remote = "http://127.0.0.1:8765";
      interval = "*:0/10";
      container = "hermes-agent";
      user = "hermes";
    };

    caddy = {
      enable = true;
      syncSubdomain = "sync";
      mcpSubdomain = null;
    };
  };
}

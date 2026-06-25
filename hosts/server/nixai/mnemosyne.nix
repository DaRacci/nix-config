_: {
  services.mnemosyne = {
    enable = true;

    server = {
      sync = {
        enable = true;
        host = "127.0.0.1";
        port = 8765;
      };

      mcp = {
        enable = false;
        host = "127.0.0.1";
        port = 8766;
      };
    };

    client.sync.hermes = {
      enable = true;
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

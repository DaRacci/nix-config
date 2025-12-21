{ config, ... }:
{
  server.proxy.virtualHosts = {
    hassio = {
      public = true;
      ports = [ 8123 ];
      extraConfig =
        let
          inherit (config.services.home-assistant.config) http;
        in
        ''
          import cors https://ai.racci.dev # Required for MCP integration

          reverse_proxy http://localhost:${toString http.server_port}
        '';
    };
  };

  services.home-assistant = {
    config.http = {
      server_port = 8123;
      use_x_forwarded_for = true;
      trusted_proxies = [
        "192.168.1.0/24"
        "192.168.2.0/24"
        "100.64.0.0/10"
      ];
    };
  };
}

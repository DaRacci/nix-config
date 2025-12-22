{
  config,
  lib,
  ...
}:
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
      trusted_proxies =
        config.server.network.subnets
        |> map (subnet: [
          subnet.ipv4.cidr
          subnet.ipv6.cidr
        ])
        |> lib.flatten
        |> lib.filterEmpty;
    };
  };
}

{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.services.mnemosyne;
in
mkIf (cfg.enable && cfg.caddy.enable) {
  server.proxy.virtualHosts = lib.mkMerge [
    (lib.optionalAttrs (cfg.server.sync.enable && cfg.caddy.syncSubdomain != null) {
      "${cfg.caddy.syncSubdomain}" = {
        ports = [ cfg.server.sync.port ];
        extraConfig = "reverse_proxy ${cfg.server.sync.host}:${toString cfg.server.sync.port}";
        requireApiKey = {
          enable = cfg.caddy.requireApiKey;
        };
      };
    })
    (lib.optionalAttrs (cfg.server.mcp.enable && cfg.caddy.mcpSubdomain != null) {
      "${cfg.caddy.mcpSubdomain}" = {
        ports = [ cfg.server.mcp.port ];
        extraConfig = "reverse_proxy ${cfg.server.mcp.host}:${toString cfg.server.mcp.port}";
        requireApiKey = {
          enable = cfg.caddy.requireApiKey;
        };
      };
    })
  ];
}

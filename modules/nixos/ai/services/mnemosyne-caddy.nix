{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkMerge optionalAttrs;

  cfg = config.services.mnemosyne;
in
mkIf (cfg.enable && cfg.caddy.enable) {
  server.proxy.virtualHosts = mkMerge [
    (optionalAttrs (cfg.server.sync.enable && cfg.caddy.syncSubdomain != null) {
      "${cfg.caddy.syncSubdomain}" = {
        ports = [ cfg.server.sync.port ];
        extraConfig = "reverse_proxy ${cfg.server.sync.host}:${toString cfg.server.sync.port}";
      };
    })

    (optionalAttrs (cfg.server.mcp.enable && cfg.caddy.mcpSubdomain != null) {
      "${cfg.caddy.mcpSubdomain}" = {
        ports = [ cfg.server.mcp.port ];
        extraConfig = "reverse_proxy ${cfg.server.mcp.host}:${toString cfg.server.mcp.port}";
      };
    })
  ];
}

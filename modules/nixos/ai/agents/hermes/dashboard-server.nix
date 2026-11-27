{ config, lib, ... }:
let
  cfg = config.services.ai-agent;
in
lib.mkIf (cfg.enable && cfg.dashboard.enable) {
  server.network.openPortsForSources.${config.server.ioPrimaryHost}.tcp = [ cfg.dashboard.port ];
}

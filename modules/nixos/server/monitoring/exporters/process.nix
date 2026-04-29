_:
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.server.monitoring;
in
{
  config = mkIf (cfg.enable && cfg.exporters.process.enable) {
    services.prometheus.exporters.process = {
      enable = true;
      process_names = [
        # Remove nix store path from process name.
        { name = "{{.Matches.Wrapped}} {{ .Matches.Args }}"; cmdline = [ "^/nix/store[^ ]*/(?P<Wrapped>[^ /]*) (?P<Args>.*)" ]; }

      ];
    };

    server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.process.port ];
  };
}

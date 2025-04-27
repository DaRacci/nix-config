{
  isNixio,
  ...
}:
{
  flake,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  serverConfigurations = lib.trivial.pipe flake.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (config: config.host.device.role == "server"))
    (builtins.filter (config: config.server.dashboard.items != { }))
  ];
in
{
  options.server.dashboard = with types; {
    name = mkOption {
      type = str;
      default = config.host.name;
      description = ''
        Name of the section in the dashboard.
      '';
    };

    displayData = mkOption {
      inherit (pkgs.formats.json { }) type;
      default = { };
      description = ''
        Display data for the section in the dashboard.
      '';
    };

    items = mkOption {
      type = attrsOf (pkgs.formats.json { }).type;
      description = ''
        Additional configuration for items managed by NixIO's dashy instance.
        This will be merged with the automatically generated configuration that is nested in a section with the name of the machine.
      '';
    };
  };

  config = lib.mkIf isNixio {
    services.dashy.settings = {
      sections = lib.pipe serverConfigurations [
        (builtins.map (config: config.server.dashboard))
        (builtins.map (
          config:
          config
          // {
            items = builtins.attrValues config.items;
          }
        ))
      ];
    };
  };
}

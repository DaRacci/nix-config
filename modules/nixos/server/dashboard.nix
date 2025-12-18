{
  isNixio,
  ...
}:
{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (types)
    submodule
    attrsOf
    nullOr
    str
    ;

  serverConfigurations = lib.trivial.pipe self.nixosConfigurations [
    builtins.attrValues
    (builtins.map (host: host.config))
    (builtins.filter (config: config.host.device.role == "server"))
    (builtins.filter (config: config.server.dashboard.items != { }))
  ];
in
{
  options.server.dashboard = {
    name = mkOption {
      type = str;
      default =
        let
          withoutPrefix = lib.removePrefix "nix" config.host.name;
          nixPrefixed = builtins.stringLength withoutPrefix < builtins.stringLength config.host.name;
        in
        if nixPrefixed then
          "Nix${lib.mine.strings.capitalise withoutPrefix}"
        else
          lib.capitalize config.host.name;
      description = ''
        Name of the section in the dashboard.
      '';
    };

    icon = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Icon for the section in the dashboard.
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
      type = attrsOf (submodule {
        options = {
          title = mkOption {
            type = str;
            description = "Title of the item.";
          };
          icon = mkOption {
            type = str;
            description = "Icon for the item.";
          };
          url = mkOption {
            type = str;
            description = "URL for the item.";
          };
        };
      });
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
        (builtins.map (config: lib.mergeAttrs config { items = builtins.attrValues config.items; }))
      ];
    };
  };
}

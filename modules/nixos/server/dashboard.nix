{
  isThisIOPrimaryHost,
  getAllAttrsFunc,
  ...
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    types
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    removePrefix
    ;
  inherit (types)
    submodule
    attrsOf
    nullOr
    str
    ;
in
{
  options.server.dashboard = {
    name = mkOption {
      type = str;
      description = "Name of the section in the dashboard.";
    };

    icon = mkOption {
      type = nullOr str;
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
        Additional configuration for items managed by the IO Hosts dashy instance.
        This will be merged with the automatically generated configuration that is nested in a section with the name of the machine.
      '';
    };
  };

  config = mkMerge [
    {
      server.dashboard = {
        name =
          let
            withoutPrefix = removePrefix "nix" config.host.name;
            nixPrefixed = builtins.stringLength withoutPrefix < builtins.stringLength config.host.name;
          in
          if nixPrefixed then
            "Nix${lib.mine.strings.capitalise withoutPrefix}"
          else
            lib.capitalize config.host.name;
      };
    }

    (mkIf isThisIOPrimaryHost {
      services.dashy.settings = {
        sections = getAllAttrsFunc "server.dashboard" (
          dashboard: _: dashboard // { items = builtins.attrValues dashboard.items; }
        );
      };
    })
  ];
}

{
  osConfig ? null,
  config,
  lib,
  ...
}:
let
  cfg = config.custom.uwsm;
in
{
  options.custom.uwsm = {
    enable = lib.mkEnableOption "Enable uwsm" // {
      default = osConfig != null && osConfig.programs.uwsm.enable;
    };

    sliceAllocation = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      description = ''
        Slice allocation for uwsm.
        This is an Attribute set where the name of the attr is the slice name,
        and the value is a list of systemd services to be allocated to that slice.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services = lib.pipe cfg.sliceAllocation [
      (lib.mapAttrsToList (
        sliceName: services:
        builtins.map (
          service:
          lib.nameValuePair service {
            Service.Slice = "${sliceName}.slice";
          }
        ) services
      ))
      lib.flatten
      lib.listToAttrs
    ];
  };
}

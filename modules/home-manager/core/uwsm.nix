{
  osConfig ? null,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    flatten
    listToAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    pipe
    ;
  inherit (lib.types) attrsOf listOf str;

  cfg = config.core.uwsm;
in
{
  options.core.uwsm = {
    enable = mkEnableOption "uwsm" // {
      default = osConfig != null && osConfig.programs.uwsm.enable;
    };

    sliceAllocation = mkOption {
      default = { };
      type = attrsOf (listOf str);
      description = ''
        Slice allocation for uwsm.
        This is an attribute set where attr name is slice name,
        and value is list of systemd services to be allocated to that slice.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services = pipe cfg.sliceAllocation [
      (mapAttrsToList (
        sliceName: services:
        map (
          service:
          nameValuePair service {
            Service.Slice = "${sliceName}.slice";
          }
        ) services
      ))
      flatten
      listToAttrs
    ];
  };
}

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
    literalExpression
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
      defaultText = literalExpression "osConfig != null && osConfig.programs.uwsm.enable";
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
    programs.bash = {
      profileExtra = ''
        PROFILE_D_ROOTS=("''${HOME}" ''${NIX_PROFILES[@]})

        for profile in "''${PROFILE_D_ROOTS[@]}"; do
          if [ -d "$profile/etc/profile.d" ]; then
            for i in "$profile/etc/profile.d/"*.sh; do
              if [ -r "$i" ]; then
                . "$i"
              fi
            done
          fi
        done
      '';
    };

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

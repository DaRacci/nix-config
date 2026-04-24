{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe mkIf mkEnableOption;
  cfg = config.core.activation;
in
{
  options.core.activation = {
    enable = mkEnableOption "report diff on activation" // {
      default = config.core.enable;
    };
  };

  config = mkIf cfg.enable {
    activationScripts.report-changes = ''
      LINKS=($(ls -dv /nix/var/nix/profiles/system-*-link))
      if [ $(echo $LINKS | wc -w) -gt 1 ]; then
        NEW=$(readlink -f ''${LINKS[-1]})
        CURRENT=$(readlink -f ''${LINKS[-2]})

        ${getExe pkgs.nvd} diff $PREVIOUS $NEW
      fi
    '';
  };
}

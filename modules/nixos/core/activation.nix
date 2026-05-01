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
    system.activationScripts.report-changes.text = ''
      CURRENT=$(readlink -f /nix/var/nix/profiles/system)
      PREVIOUS=$(ls -dv /nix/var/nix/profiles/system-*-link 2>/dev/null | tail -n 2 | head -n 1)
      NEW=$(ls -dv /nix/var/nix/profiles/system-*-link 2>/dev/null | tail -n 1)

      if [ -n "$PREVIOUS" ] && [ -n "$NEW" ]; then
        CURRENT=$(readlink -f "$PREVIOUS")
        NEW=$(readlink -f "$NEW")

        ${getExe pkgs.nvd} diff "$CURRENT" "$NEW" || true
      fi
    '';
  };

}

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    getExe
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
    optionalString
    ;
  inherit (builtins) length;

  cfg = config.core.display-manager;
  sessions = config.services.displayManager.sessionPackages;
  waylandSessionPaths = concatStringsSep ":" (map (pkg: "${pkg}/share/wayland-sessions") sessions);
  xSessionPaths = concatStringsSep ":" (map (pkg: "${pkg}/share/xsessions") sessions);
in
{
  options.core.display-manager = {
    enable = mkEnableOption "display manager configuration";
  };

  config = mkMerge [
    {
      core.display-manager.enable = mkDefault (!config.host.device.isHeadless);
    }

    (mkIf cfg.enable {
      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = ''
              ${getExe pkgs.tuigreet} \
                --time \
                --remember \
                --remember-session ${
                  optionalString (
                    length sessions > 0
                  ) "--sessions '${waylandSessionPaths}' --xsessions '${xSessionPaths}'"
                }
            '';
            user = "greeter";
          };
        };
      };

      host.persistence.directories = [ "/var/cache/tuigreet" ];
    })
  ];
}

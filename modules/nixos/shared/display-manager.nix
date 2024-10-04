{ config, pkgs, lib, ... }: with lib; let
  cfg = config.custom.display-manager;
  sessions = config.services.displayManager.sessionPackages;
  waylandSessionPaths = builtins.concatStringsSep ":" (map (pkg: "${pkg}/share/wayland-sessions") sessions);
  xSessionPaths = builtins.concatStringsSep ":" (map (pkg: "${pkg}/share/xsessions") sessions);
in
{
  options.custom.display-manager = {
    enable = (mkEnableOption "Enable custom display manager configuration") // {
      default = !config.host.device.isHeadless;
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${lib.getExe pkgs.greetd.tuigreet} --time --remember --remember-session --sessions '${waylandSessionPaths}' --xsessions '${xSessionPaths}'";
          user = "greeter";
        };
      };
    };

    host.persistence.directories = [ "/var/cache/tuigreet" ];
  };
}

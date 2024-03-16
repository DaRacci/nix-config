{ config, pkgs, lib, ... }: with lib; let cfg = config.custom.display-manager; in {
  options.custom.display-manager = {
    enable = (mkEnableOption "Enable custom display manager configuration") // { default = config.host.device.role != "server"; };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = false;
      package = pkgs.greetd;

      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${pkgs.greetd.regreet}/bin/regreet";
          #command = "${pkgs.unstable.greetd.tuigreet}/bin/tuigreet --time "; #--remember --remember-user-session --asterisks --power-shutdown '${pkgs.systemd}/bin/shutdown -h now' --power-reboot '${pkgs.systemd}/bin/shutdown -r now'";
          user = "greeter";
        };
      };
    };
  };
}

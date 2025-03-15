{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.gauntlet.homeManagerModules.default
  ];

  programs.gauntlet = {
    enable = true;
    service.enable = false;
    config = {

    };
  };

  wayland.windowManager.hyprland.extraConfig = ''
    bind=CTRL_ALT,SPACE,exec,${lib.getExe config.programs.gauntlet.package} open
  '';

  systemd.user.services.gauntlet = {
    Unit = {
      Description = "Gauntlet";
      PartOf = "graphical-session.target";
      After = "graphical-session.target";
    };

    Service = {
      Type = "exec";
      Restart = "on-failure";
      ExecStart = "${lib.getExe config.programs.gauntlet.package} --minimized";
      Slice = "app-graphical.slice";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  user.persistence.directories = [
    ".local/share/gauntlet"
    ".config/gauntlet"
  ];
}

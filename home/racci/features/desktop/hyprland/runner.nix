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
    service.enable = true;
    config = {

    };
  };

  user.persistence.directories = [
    ".local/share/gauntlet"
    ".config/gauntlet"
  ];

  wayland.windowManager.hyprland.extraConfig = ''
    bind=CTRL_ALT,SPACE,exec,${lib.getExe config.programs.gauntlet.package} open
  '';
}

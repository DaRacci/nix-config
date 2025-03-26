{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe getExe';
in
{
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER,V,exec,${getExe' pkgs.uwsm "uwsm-app"} -s a -- ${getExe config.programs.rofi.package} -modi clipboard:~/.local/bin/cliphist-rofi-img -show clipboard -show-icons"
  ];

  home.packages = with pkgs; [
    wl-clipboard
  ];

  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  home.file.".local/bin/cliphist-rofi-img" = {
    executable = true;
    source = "${
      pkgs.writeShellApplication {
        name = "cliphist-rofi-img";
        runtimeInputs = with pkgs; [
          config.services.cliphist.package
          config.programs.rofi.package
          gawk
          wl-clipboard
          imagemagick
        ];
        bashOptions = [ ];
        excludeShellChecks = [ "SC2086" ];
        text =
          lib.trivial.pipe
            "https://raw.githubusercontent.com/sentriz/cliphist/master/contrib/cliphist-rofi-img"
            [
              builtins.fetchurl
              builtins.readFile
            ];
      }
    }/bin/cliphist-rofi-img";
  };

  systemd.user.services = {
    cliphist.Service.Slice = "background.slice";
    cliphist-images.Service.Slice = "background.slice";
  };
}

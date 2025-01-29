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
  wayland.windowManager.hyprland.settings = {
    exec-once =
      let
        wl-paste = getExe' pkgs.wl-clipboard "wl-paste";
      in
      [
        "${wl-paste} --type text --watch cliphist store"
        "${wl-paste} --type image --watch cliphist store"
      ];

    bind = [
      "SUPER,V,exec,${getExe config.programs.rofi.package} -modi clipboard:~/.local/bin/cliphist-rofi-img -show clipboard -show-icons"
    ];
  };

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
}

{ config, pkgs, lib, ... }:
let inherit (lib) getExe getExe'; in {
  wayland.windowManager.hyprland.settings = {
    exec-once =
      let
        wl-paste = getExe' pkgs.wl-clipboard "wl-paste";
        # wl-copy = getExe' pkgs.wl-clipboard "wl-copy";
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
    source = "${pkgs.writeShellApplication {
      name = "cliphist-rofi-img";
      runtimeInputs = [ config.services.cliphist.package pkgs.gawk ];
      text = builtins.readFile (builtins.fetchurl {
        url = "https://raw.githubusercontent.com/sentriz/cliphist/master/contrib/cliphist-rofi-img";
      });
    }}/bin/cliphist-rofi-img";
  };
}

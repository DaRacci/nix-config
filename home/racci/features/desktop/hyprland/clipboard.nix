{ pkgs, lib, ... }:
let inherit (lib) getExe getExe'; in {
  wayland.windowManager.hyprland.settings = {
    exec-once =
      let
        wl-paste = getExe' pkgs.wl-clipboard "wl-paste";
        # wl-copy = getExe' pkgs.wl-clipboard "wl-copy";
      in
      [
        "${getExe pkgs.wl-clip-persist} --clipboard regular"
        "${wl-paste} --type text --watch cliphist store"
        "${wl-paste} --type image --watch cliphist store"
      ];
  };

  services.cliphist = {
    enable = true;
    allowImages = true;
  };
}

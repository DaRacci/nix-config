{ pkgs, lib, ... }: {
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "${lib.getExe' pkgs.wl-clipboard "wl-paste"} --primary --watch wl-copy --primary --clear"
    ];
  };
}
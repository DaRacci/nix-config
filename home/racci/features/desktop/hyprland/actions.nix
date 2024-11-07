{ pkgs, lib, ... }:
let inherit (lib) getExe getExe'; in {
  wayland.windowManager.hyprland.settings = {
    bind = [
      # OCR
      "Super+Shift,T,exec,${getExe pkgs.grim} -g \"$(${getExe pkgs.slurp} $SLURP_ARGS)\" \"tmp.png\" && ${getExe pkgs.tesseract} \"tmp.png\" - | ${getExe' pkgs.wl-clipboard "wl-copy"} && rm \"tmp.png\""

      # Color Picker
      # TODO: Lower Cursor Speed, Allow zooming in and out with mouse wheel
      "Super+Shift,C,exec,${getExe pkgs.hyprpicker} -a"
    ];
  };
}

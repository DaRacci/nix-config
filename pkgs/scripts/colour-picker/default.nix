{
  lib,
  writeShellApplication,

  gojq,
  hyprland,
  hyprpicker,
  wl-clipboard,
}:
writeShellApplication {
  name = "colour-picker";
  text = builtins.readFile ./colour-picker.sh;
  runtimeInputs = [
    hyprpicker
    wl-clipboard
    hyprland
    gojq
  ];

  meta = {
    description = "A script to pick a colour from the screen and copy it to the clipboard";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}

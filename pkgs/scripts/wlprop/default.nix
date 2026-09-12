{
  lib,
  writeShellApplication,

  hyprland,
  slurp,
  jq,
}:
writeShellApplication {
  name = "wlprop";
  text = builtins.readFile ./wlprop.sh;
  runtimeInputs = [
    hyprland
    slurp
    jq
  ];

  meta = {
    description = "A script to get the properties of a window in Hyprland";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}

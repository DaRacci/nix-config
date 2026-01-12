{
  writeShellApplication,

  coreutils,
  hyprland,
  jq,
  procps,
  socat,
}:
writeShellApplication {
  name = "hypr-gamemode";
  text = builtins.readFile ./hypr-gamemode.sh;
  runtimeInputs = [
    coreutils
    hyprland
    jq
    procps
    socat
  ];
}

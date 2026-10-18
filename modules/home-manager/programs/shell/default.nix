{
  osConfig ? null,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./completions.nix
    ./multiplexer.nix
    ./prompt.nix
    ./shell.nix
    ./tools.nix
  ];

  options.programSets.shell = {
    enable = mkEnableOption "shell" // {
      default = osConfig == null || osConfig.host.device.role != "server";
      defaultText = "true if the device is not a server";
    };
  };
}

{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [
    ./shell.nix
  ];

  options.security = {
    enable = mkEnableOption "If security auto-configuration should happen.";
  };

  config = { };
}

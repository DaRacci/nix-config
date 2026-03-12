{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "jvm";

  extraConfig = {
    home.packages = [ pkgs.jetbrains.idea-community ];
  };
}

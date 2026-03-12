{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "powershell";

  lspPackages = [ pkgs.powershell-editor-services ];
  extraPackages = [ pkgs.powershell ];
}

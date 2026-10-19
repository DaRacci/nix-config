{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "lua";

  lspPackages = [ pkgs.lua-language-server ];
}

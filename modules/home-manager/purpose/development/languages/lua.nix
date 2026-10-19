{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    ;
in
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "lua";

  lspPackages = [ pkgs.lua-language-server ];

  extraConfig = {
    programs.zed-editor = {
      extensions = [ "lua" ];
      userSettings.lsp.lua-language-server = {
        binary.path = getExe pkgs.lua-language-server;
      };
    };
  };
}

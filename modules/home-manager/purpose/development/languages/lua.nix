{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "lua";

  lsp = [
    {
      name = "lua-language-server";
      package = pkgs.lua-language-server;
      filetypes = [ ".lua" ];
    }
  ];

  formatters = [
    {
      name = "stylua";
      package = pkgs.stylua;
      args = [ "-" ];
      filetypes = [ ".lua" ];
    }
  ];

  editors = {
    zed.extensions = [ "lua" ];
    vscode = {
      profile = "default";
      extensions = [ "sumneko.lua" ];
    };
  };
}

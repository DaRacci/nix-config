{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "nu";

  lsp = [
    {
      name = "nushell";
      package = pkgs.nushell;
      binary = "nu";
      args = [ "--lsp" ];
      filetypes = [ ".nu" ];
    }
  ];

  extraPackages = [ pkgs.nushell ];

  editors = {
    zed.extensions = [ "nu" ];
    vscode = {
      profile = "default";
      extensions = [ "thenuprojectcontributors.vscode-nushell-lang" ];
    };
  };
}

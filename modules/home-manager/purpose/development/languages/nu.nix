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
      languages = [ "Nu" ];
    }
  ];

  extraPackages = [ pkgs.nushell ];

  editors = {
    zed = {
      extensions = [ "nu" ];
      languages = [ "Nu" ];
    };
    helix.languages = [ "nu" ];
    vscode = {
      profile = "default";
      extensions = [ "thenuprojectcontributors.vscode-nushell-lang" ];
    };
  };
}

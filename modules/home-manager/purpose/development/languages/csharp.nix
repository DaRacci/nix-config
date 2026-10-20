{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "csharp";

  treesitterPackages = [ pkgs.tree-sitter-grammars.tree-sitter-c-sharp ];

  lsp = [
    {
      name = "roslyn-ls";
      package = pkgs.roslyn-ls;
      filetypes = [ ".cs" ];
    }
  ];

  formatters = [
    {
      name = "csharpier";
      package = pkgs.csharpier;
      args = [ "--write-stdout" ];
      filetypes = [ ".cs" ];
    }
  ];

  editors.zed.languages = [ "C#" ];
}

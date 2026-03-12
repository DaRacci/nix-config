{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "csharp";

  treesitterPackage = pkgs.tree-sitter-grammars.tree-sitter-c-sharp;
  lspPackages = [ pkgs.roslyn-ls ];
}

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
  lspPackages = [ pkgs.roslyn-ls ];
}

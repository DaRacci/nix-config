{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "jvm";

  treesitterPackages = [
    pkgs.tree-sitter-grammars.tree-sitter-java
    pkgs.tree-sitter-grammars.tree-sitter-kotlin
    pkgs.tree-sitter-grammars.tree-sitter-scala
  ];

  extraConfig = {
    home.packages = [ pkgs.jetbrains.idea-community ];
  };
}

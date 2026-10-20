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

  lsp = [
    {
      name = "jdtls";
      package = pkgs.jdt-language-server;
      languages = [ "Java" ];
      filetypes = [ ".java" ];
    }
    {
      name = "kotlin-language-server";
      package = pkgs.kotlin-language-server;
      languages = [ "Kotlin" ];
      filetypes = [
        ".kt"
        ".kts"
      ];
    }
    {
      name = "metals";
      package = pkgs.metals;
      languages = [ "Scala" ];
      filetypes = [
        ".scala"
        ".sc"
      ];
    }
  ];

  formatters = [
    {
      name = "google-java-format";
      package = pkgs.google-java-format;
      args = [ "-" ];
      languages = [ "Java" ];
      filetypes = [ ".java" ];
    }
    {
      name = "ktlint";
      package = pkgs.ktlint;
      languages = [ "Kotlin" ];
      filetypes = [
        ".kt"
        ".kts"
      ];
    }
  ];

  editors.zed.extensions = [
    "java"
    "kotlin"
    "scala"
  ];

  extraConfig = {
    home.packages = [ pkgs.jetbrains.idea-community ];
  };
}

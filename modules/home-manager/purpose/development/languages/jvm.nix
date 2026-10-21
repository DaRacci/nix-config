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
      languages = [ "java" ];
      filetypes = [ ".java" ];
    }
    {
      name = "kotlin-language-server";
      package = pkgs.kotlin-language-server;
      languages = [ "kotlin" ];
      filetypes = [
        ".kt"
        ".kts"
      ];
    }
    {
      name = "metals";
      package = pkgs.metals;
      languages = [ "scala" ];
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
      languages = [ "java" ];
      filetypes = [ ".java" ];
      editors.opencode.command = [
        "google-java-format"
        "--replace"
        "$FILE"
      ];
    }
    {
      name = "ktlint";
      package = pkgs.ktlint;
      args = [
        "--format"
        "--stdin"
        "--log-level=none"
      ];
      languages = [ "kotlin" ];
      filetypes = [
        ".kt"
        ".kts"
      ];
      editors.opencode.command = [
        "ktlint"
        "-F"
        "$FILE"
      ];
    }
  ];

  editors = {
    zed.extensions = [
      "java"
      "kotlin"
      "scala"
    ];

    vscode.profile = "jvm";
  };

  extraConfig = {
    home.packages = [ pkgs.jetbrains.idea-community ];
  };
}

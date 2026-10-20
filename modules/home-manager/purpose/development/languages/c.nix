{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "c";

  treesitterPackages = [
    pkgs.tree-sitter-grammars.tree-sitter-c
    pkgs.tree-sitter-grammars.tree-sitter-cpp
  ];

  lsp = [
    {
      name = "clangd";
      package = pkgs.clang-tools;
      binary = "clangd";
      filetypes = [
        ".c"
        ".h"
        ".cpp"
        ".hpp"
        ".cc"
        ".cxx"
        ".hxx"
      ];
      languages = [
        "C"
        "C++"
      ];
    }
  ];

  formatters = [
    {
      name = "clang-format";
      package = pkgs.clang-tools;
      binary = "clang-format";
      filetypes = [
        ".c"
        ".h"
        ".cpp"
        ".hpp"
        ".cc"
        ".cxx"
        ".hxx"
      ];
      languages = [
        "C"
        "C++"
      ];
    }
  ];

  editors = {
    zed = {
      extensions = [
        "c"
        "cpp"
      ];
      languages = [
        "C"
        "C++"
      ];
    };
    helix.languages = [
      "c"
      "cpp"
    ];
    vscode = {
      profile = "default";
      extensions = [ "ms-vscode.cpptools" ];
    };
  };
}

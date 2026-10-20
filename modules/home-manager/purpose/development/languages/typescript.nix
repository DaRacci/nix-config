{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "typescript";

  lsp = [
    {
      name = "typescript-language-server";
      package = pkgs.typescript-language-server;
      args = [ "--stdio" ];
      filetypes = [
        ".ts"
        ".tsx"
        ".js"
        ".jsx"
        ".mjs"
        ".cjs"
      ];
      languages = [
        "typescript"
        "javascript"
      ];
    }
  ];

  extraPackages = [
    pkgs.nodejs
    pkgs.typescript
  ];

  editors.vscode = {
    profile = "default";
    extensions = [ "dbaeumer.vscode-eslint" ];
  };
}

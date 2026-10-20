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
        "TypeScript"
        "JavaScript"
      ];
    }
  ];

  extraPackages = [
    pkgs.nodejs
    pkgs.typescript
  ];

  editors = {
    zed.languages = [
      "TypeScript"
      "JavaScript"
    ];
    helix.languages = [
      "typescript"
      "javascript"
    ];
    vscode = {
      profile = "default";
      extensions = [ "dbaeumer.vscode-eslint" ];
    };
  };
}

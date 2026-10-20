{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "go";

  lsp = [
    {
      name = "gopls";
      package = pkgs.gopls;
      filetypes = [ ".go" ];
      languages = [ "Go" ];
    }
  ];

  formatters = [
    {
      name = "gofmt";
      package = pkgs.go;
      binary = "gofmt";
      filetypes = [ ".go" ];
      languages = [ "Go" ];
      editors.opencode.command = [
        "gofmt"
        "-w"
        "$FILE"
      ];
    }
  ];

  extraPackages = [ pkgs.go ];

  editors = {
    zed.languages = [ "Go" ];
    helix.languages = [ "go" ];
    vscode = {
      profile = "default";
      extensions = [ "golang.go" ];
    };
  };
}

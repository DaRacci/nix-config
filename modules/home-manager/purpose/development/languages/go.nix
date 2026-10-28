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

      # formats with gofmt
      providesFormatting = true;
    }
  ];

  formatters = [
    {
      name = "gofmt";
      package = pkgs.go;
      binary = "gofmt";
      filetypes = [ ".go" ];
      editors.opencode.command = [
        "gofmt"
        "-w"
        "$FILE"
      ];
    }
  ];

  extraPackages = [ pkgs.go ];

  editors.vscode = {
    profile = "default";
    extensions = [ "golang.go" ];
  };
}

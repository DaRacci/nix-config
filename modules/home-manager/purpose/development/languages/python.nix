{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "python";

  lsp = [
    {
      name = "pyright";
      package = pkgs.pyright;
      binary = "pyright-langserver";
      args = [ "--stdio" ];
      filetypes = [ ".py" ];
    }
  ];

  formatters = [
    {
      name = "black";
      package = pkgs.black;
      args = [ "-" ];
      filetypes = [ ".py" ];
    }
  ];

  editors.vscode = {
    profile = "python";
    extensions = [
      "ms-python.python"
      "ms-python.vscode-pylance"
      "ms-python.debugpy"
      "ms-python.black-formatter"
      "ms-python.isort"
      "ms-python.pylint"
      "ms-python.mypy-type-checker"
      "ms-python.gather"
    ];
  };
}

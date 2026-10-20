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

  editors.zed.languages = [ "Python" ];
}

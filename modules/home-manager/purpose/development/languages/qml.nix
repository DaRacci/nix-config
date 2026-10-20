{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "qml";

  lsp = [
    {
      name = "qmlls";
      package = pkgs.kdePackages.qtdeclarative;
      binary = "qmlls";
      args = [ "-E" ];
      filetypes = [ ".qml" ];
    }
  ];

  editors = {
    zed.extensions = [ "qml" ];
    vscode = {
      profile = "default";
      extensions = [ "theqtcompany.qt-core" ];
    };
  };
}

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
      languages = [ "QML" ];
    }
  ];

  editors = {
    zed = {
      extensions = [ "qml" ];
      languages = [ "QML" ];
    };
    helix.languages = [ "qml" ];
    vscode = {
      profile = "default";
      extensions = [ "theqtcompany.qt-core" ];
    };
  };
}

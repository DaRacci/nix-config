{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    ;
in
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "powershell";

  lspPackages = [ pkgs.powershell-editor-services ];
  extraPackages = [ pkgs.powershell ];

  extraConfig = {
    programs.zed-editor = {
      extensions = [ "powershell" ];
      userSettings.lsp.powershell-es = {
        binary.path = getExe pkgs.powershell-editor-services;
      };
    };
  };
}

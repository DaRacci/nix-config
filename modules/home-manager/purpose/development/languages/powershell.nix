{
  config,
  pkgs,
  lib,
  ...
}:
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "powershell";

  lsp = [
    {
      name = "powershell-es";
      package = pkgs.powershell-editor-services;
      filetypes = [
        ".ps1"
        ".psm1"
        ".psd1"
      ];
    }
  ];

  extraPackages = [ pkgs.powershell ];

  editors.zed = {
    extensions = [ "powershell" ];
    languages = [ "PowerShell" ];
  };
}

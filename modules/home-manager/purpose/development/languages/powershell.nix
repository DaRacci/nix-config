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
      binary = "powershell-editor-services";
      args = [ "-Stdio" ];
      filetypes = [
        ".ps1"
        ".psm1"
        ".psd1"
      ];
      editors.helix.args = [
        "-Stdio"
        "-HostName 'Helix'"
        "-HostProfileId 0"
        "-HostVersion 1.0.0"
        "-LogLevel 'Information'"
      ];
    }
  ];

  extraPackages = [ pkgs.powershell ];

  editors = {
    zed.extensions = [ "powershell" ];
    vscode = {
      profile = "dotnet";
      extensions = [
        "ms-vscode.powershell"
        "pspester.pester-test"
        "ironmansoftware.powershellprotools"
        "tylerleonhardt.vscode-inline-values-powershell"
      ];
      settings = {
        # Required by ironmansoftware.powershellprotools
        "terminal.integrated.enablePersistentSessions" = false;
      };
    };
  };
}

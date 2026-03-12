{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.editors.helix;
in
{
  options.purpose.development.editors.helix = {
    enable = mkEnableOption "Helix Editor";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.purpose.development.editors.enable;
        message = "You have enabled the Helix editor but not development editors. Ensure that `purpose.development.editors.helix` is set to true.";
      }
    ];

    programs.helix = {
      enable = true;
      extraPackages = [
        pkgs.powershell
        pkgs.powershell-editor-services
      ];
      ignores = [ ];
      languages = [
        {
          name = "pwsh";
          scope = "source.ps1";
          roots = [ ".git" ];
          file-types = [
            "ps1"
            "psm1"
            "psd1"
          ];
          comment-token = "#";
          indent = {
            tab-width = 2;
            unit = "space";
          };
          language-server = {
            command = lib.getExe pkgs.powershell-editor-services;
            args = [
              "-Stdio"
              "-HostName 'Helix'"
              "-HostProfileId 0"
              "-HostVersion 1.0.0"
              "-LogLevel 'Normal'"
              "-FeatureFlags @()"
              "-AdditionalModules @()"
              "-BundledModulesPath ${pkgs.powershell-editor-services}/lib/powershell-editor-services"
              "-SessionDetailsPath $XDG_STATE_HOME/powershell/sessions.json"
              "-LogPath $XDG_STATE_HOME/powershell/editor.log"
            ];
          };
        }
      ];
      settings = { };
    };
  };
}

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
    programs.helix = {
      enable = true;
      extraPackages = [
        pkgs.powershell
        pkgs.powershell-editor-services
        pkgs.tree-sitter-grammars.tree-sitter-powershell
      ];

      settings = {
        editor = {
          middle-click-paste = false;
          trim-final-newlines = true;
          trim-trailing-whitespace = true;

          end-of-line-diagnostics = "hint";

          lsp = {
            display-progress-messages = true;
            display-inlay-hints = true;
          };

          indent-guides.render = true;
          inline-diagnostics = {
            cursor-line = "hint";
            other-lines = "info";
          };
        };
      };
      ignores = [ ];

      languages = {
        language = [
          {
            name = "powershell";
            roots = [ ".git" ];
            language-servers = [ "powershell-editor-services" ];
          }
        ];

        language-server = {
          powershell-editor-services = {
            name = "powershell-editor-services";
            command = lib.getExe pkgs.powershell-editor-services;
            args = [
              "-Stdio"
              "-HostName 'Helix'"
              "-HostProfileId 0"
              "-HostVersion 1.0.0"
              "-LogLevel 'Information'"
              "-BundledModulesPath ${pkgs.powershell-editor-services}/lib/powershell-editor-services"
              "-SessionDetailsPath ${config.xdg.stateHome}/powershell/sessions.json"
              "-LogPath ${config.xdg.stateHome}/powershell/editor.log"
            ];
          };
        };
      };
    };
  };
}

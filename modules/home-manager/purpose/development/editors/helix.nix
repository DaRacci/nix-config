{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (builtins) filter;
  inherit (lib)
    concatLists
    mkEnableOption
    mkIf
    mkMerge
    ;

  cfg = config.purpose.development.editors.helix;
  languageCfg = config.purpose.development.languages;
in
{
  options.purpose.development.editors.helix = {
    enable = mkEnableOption "Helix Editor";
  };

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;
      extraPackages = [
        pkgs.bash-language-server
        pkgs.cmake-language-server
        pkgs.clang-tools
      ]
      ++ (
        builtins.attrValues languageCfg
        |> filter (langCfg: builtins.isAttrs langCfg)
        |> filter (langCfg: langCfg.enable)
        |> map (langCfg: langCfg.allPackages)
        |> concatLists
      );

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

      languages = mkMerge [
        (mkIf languageCfg.powershell.enable {
          language = [
            {
              name = "powershell";
              roots = [ ".git" ];
              language-servers = [ "powershell-editor-services" ];
            }
          ];

          language-server.powershell-editor-services = {
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
        })

        (mkIf languageCfg.nix.enable {
          language = [
            {
              name = "nix";
              roots = [ "flake.nix" ];
              language-servers = [
                "nixd"
                "nil"
              ];
            }
          ];

          language-server.nixd = {
            name = "nixd";
            command = lib.getExe pkgs.nixd;
            args = [
              "--semantic-tokens"
              "--inlay-hints"
            ]
            ++ (lib.optionals (config.system != null) [
              "--nixos-options-expr (builtins.getFlake (builtins.toString ./.)).nixosConfigurations.(${config.system.host.name}).options"
            ]);
          };
        })
      ];
    };
  };
}

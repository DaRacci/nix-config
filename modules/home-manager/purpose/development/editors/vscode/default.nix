{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development;
in
{
  options.purpose.development.editors.vscode = {
    enable = lib.mkEnableOption "Enable VSCode" // {
      default = cfg.enable;
    };
  };

  config = lib.mkIf (cfg.enable && cfg.editors.vscode.enable) {
    stylix.targets.vscode.profileNames = [ "default" ];

    programs.vscode = {
      enable = true;
      mutableExtensionsDir = false;

      profiles =
        let
          extensions = inputs.vscode-extensions.extensions.${pkgs.stdenv.system};
          versionExtensions = extensions.forVSCodeVersion config.programs.vscode.package.version;
          plugins = (import ./extensions.nix) { inherit pkgs lib; };

          commonProfile = {
            enableExtensionUpdateCheck = false;
            enableUpdateCheck = false;

            extensions = with plugins; [
              # Theme & Looks
              pkief.material-icon-theme
              aaron-bond.better-comments
              wayou.vscode-todo-highlight

              # Workspaces & Projects
              mkhl.direnv
              editorconfig.editorconfig
              alefragnani.project-manager
              ms-vscode-remote.remote-ssh

              # Sidebar Additions
              gruntfuggly.todo-tree
              eamodio.gitlens

              # Language Support
              redhat.vscode-xml
              versionExtensions.vscode-marketplace.redhat.vscode-yaml
              tamasfe.even-better-toml
              matthewpi.caddyfile-support
              coolbear.systemd-unit-file
              hashicorp.terraform
              bierner.markdown-preview-github-styles
              ruschaaf.extended-embedded-languages

              # LSP Servers
              jnoortheen.nix-ide
              ms-vscode.powershell

              # Formatters
              esbenp.prettier-vscode

              # Containers
              ms-azuretools.vscode-docker

              # AI
              github.copilot
              github.copilot-chat

              # Other
              formulahendry.code-runner
              # platformio.platformio-ide

              # Bash Extensions
              rogalmic.bash-debug
              foxundermoon.shell-format

              # Integrations
              github.vscode-github-actions
              github.vscode-pull-request-github
            ];

            userSettings = {
              #region Look & Feel
              "workbench.startupEditor" = "none";
              "workbench.iconTheme" = "material-icon-theme";

              "window.zoomLevel" = 3;
              "window.titleBarStyle" = "custom";

              "explorer.excludeGitIgnore" = true;
              #endregion

              "editor.formatOnSave" = true;
              "editor.autoClosingQuotes" = "always";
              "editor.autoClosingBrackets" = "always";
              "editor.inlineSuggest.enabled" = true;
              "editor.mouseWheelZoom" = true;
              "editor.inlineSuggest.syntaxHighlightingEnabled" = true;
              "editor.suggest.preview" = true;
              "editor.suggest.shareSuggestSelections" = true;

              "github.copilot.enable"."*" = true;
              "github.copilot.advanced".indentationMode."*" = true;

              "files.autoSave" = "afterDelay";
              "files.eol" = "\n";

              #region Git & Diff
              "git.autofetch" = true;
              "git.confirmSync" = false;
              "git.allowForcePush" = true;
              "git.allowNoVerifyCommit" = true;
              "git.autoStash" = true;
              "git.blame.statusBarItem.enabled" = true;

              "diffEditor.hideUnchangedRegions.enabled" = true;
              "diffEditor.ignoreTrimWhitespace" = false;
              #endregion

              #region Language Settings
              "[jsonc]" = {
                "editor.defaultFormatter" = "vscode.json-language-features";
              };
              #endregion

              #region Language Formattings
              "evenBetterToml.formatter.alignComments" = true;
              "evenBetterToml.formatter.alignEntries" = true;
              "evenBetterToml.formatter.allowedBlankLines" = 1;
              "evenBetterToml.formatter.arrayAutoCollapse" = true;
              "evenBetterToml.formatter.arrayAutoExpand" = true;
              "evenBetterToml.formatter.arrayTrailingComma" = true;
              "evenBetterToml.formatter.columnWidth" = 80;
              #endregion

              #region Telemetry & Data Collection
              "telemetry.telemetryLevel" = "off";
              "redhat.telemetry.enabled" = false;
              "gitlens.telemetry.enabled" = false;
              "code-runner.enableAppInsights" = false;
              #endregion

              #region Annoyances
              "gitlens.showWhatsNewAfterUpgrades" = false;
              #endregion

              #region Extensions
              "extensions.ignoreRecommendations" = true;

              "direnv.restart.automatic" = true;
              "direnv.status.showChangesCount" = true;

              "caddyfile.executable" = "${lib.getExe pkgs.caddy}";

              "gitlens.plusFeatures.enabled" = false;
              "gitlens.graph.layout" = "editor";
              "gitlens.launchpad.indicator.enabled" = false;
              "gitlens.cloudPatches.enabled" = false;
              "gitlens.views.commits.showStashes" = true;
              "gitlens.views.repositories.showStashes" = true;

              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "${lib.getExe pkgs.nil}";
              "nix.serverSettings" = {
                nil = {
                  diagnostics = {
                    ignored = [ ];
                  };
                  formatting = {
                    command = [ "${lib.getExe pkgs.nixfmt-rfc-style}" ];
                  };
                };

                nixd = {
                  formatting.command = "${lib.getExe pkgs.nixfmt-rfc-style}";
                  eval = {
                    enable = true;
                    targets = {
                      args = [
                        "-f"
                        "default.nix"
                      ];
                      installable = "";
                    };
                  };
                  options = {
                    enable = true;
                    targets = {
                      args = [
                        "-f"
                        "default.nix"
                      ];
                      installable = "";
                      # installable = "/flakeref#nixosConfigurations.nixe.options";
                    };
                  };
                };
              };
              #endregion

              #region Security
              "security.promptForLocalFileProtocolHandling" = false;
              "security.workspace.trust.enabled" = false;
              #endregion

              # "platformio-ide.customPATH" = "${pkgs.platformio}/bin/platformio";
              # "platformio-ide.useBuiltinPython" = false;
              # "platformio-ide.useBuiltinPIOCore" = false;
              # "platformio-ide.pioHomeServerHttpPort" = 8008;
            };
          };
          mkProfile =
            attrs:
            let
              providedAttrs = lib.mine.attrsets.recursiveMerge [
                commonProfile
                attrs
              ];
            in
            lib.mine.attrsets.recursiveMerge [
              providedAttrs
              {
                userSettings = {
                  "settings.ignoredExtensions" = lib.map (ext: ext.vscodeExtUniqueId) providedAttrs.extensions;
                  "workbench.settings.applyToAllProfiles" = builtins.attrNames providedAttrs.userSettings;
                };
              }
            ];
        in
        {
          default = mkProfile { };

          jvm = lib.mkIf cfg.jvm.enable (mkProfile {

          });

          rust = lib.mkIf cfg.rust.enable (mkProfile {
            extensions = with plugins; [
              versionExtensions.vscode-marketplace.vadimcn.vscode-lldb
              jscearcy.rust-doc-viewer
              dustypomerleau.rust-syntax
              rust-lang.rust-analyzer
            ];
          });

          python = lib.mkIf cfg.python.enable (mkProfile {
            extensions = with plugins.ms-python; [
              python
              vscode-pylance
              debugpy
              black-formatter
              isort
              pylint
              mypy-type-checker
              gather
            ];
          });
        };
    };

    home.file.".vscode/argv.json" = {
      text = ''
        {
          "enable-crash-reporter": false,
          "password-store": "gnome-libsecret"
        }
      '';
    };

    user.persistence.directories = [ ".config/Code/User/" ];
  };
}

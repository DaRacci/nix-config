{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development;

  profiles = [
    "default"
    "rust"
    "jvm"
    "dotnet"
    "python"
  ];
in
{
  options.purpose.development.editors.vscode = {
    enable = lib.mkEnableOption "Enable VSCode" // {
      default = cfg.enable;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.editors.vscode.enable) {
      nixpkgs.overlays = [
        inputs.nix4vscode.overlays.default
      ];

      programs.vscode = {
        enable = true;
        mutableExtensionsDir = false;

        profiles =
          let
            versionExtensions = pkgs.nix4vscode.forVscodeVersion config.programs.vscode.package.version;

            commonProfile = {
              extensions = versionExtensions [
                # Theme & Looks
                "pkief.material-icon-theme"
                "aaron-bond.better-comments"
                "wayou.vscode-todo-highlight"

                # Workspaces & Projects
                "mkhl.direnv"
                "editorconfig.editorconfig"
                "alefragnani.project-manager"
                "ms-vscode-remote.remote-ssh"

                # Sidebar Additions
                "gruntfuggly.todo-tree"
                "eamodio.gitlens"

                # Language Support
                "redhat.vscode-xml"
                "redhat.vscode-yaml"
                "tamasfe.even-better-toml"
                "matthewpi.caddyfile-support"
                "coolbear.systemd-unit-file"
                "hashicorp.terraform"
                "bierner.markdown-preview-github-styles"
                "ruschaaf.extended-embedded-languages"
                "jamief.vscode-ssh-config-enhanced"
                "keesschollaart.vscode-home-assistant"
                "owensimon.combinatorc"

                # LSP Servers
                "jnoortheen.nix-ide"

                # Formatters
                "esbenp.prettier-vscode"

                # Containers
                "ms-azuretools.vscode-docker"

                # AI
                "github.copilot"
                "github.copilot-chat"

                # Other
                "formulahendry.code-runner"
                "markis.code-coverage"
                "vadimcn.vscode-lldb"
                "platformio.platformio-ide"

                # Bash Extensions
                "rogalmic.bash-debug"
                "foxundermoon.shell-format"

                # Integrations
                "github.vscode-github-actions"
                "github.vscode-pull-request-github"
              ];

              userSettings = {
                #region Look & Feel
                "workbench.startupEditor" = "none";

                "workbench.iconTheme" = "material-icon-theme";
                "markdown-preview-github-styles.colorTheme" = "dark";

                "window.zoomLevel" = 3;
                "window.titleBarStyle" = "custom";

                "terminal.integrated.fontSize" = lib.mkForce 12;

                "explorer.excludeGitIgnore" = true;
                #endregion

                "editor.formatOnSave" = true;
                "editor.formatOnSaveMode" = "modificationsIfAvailable";
                "editor.autoClosingQuotes" = "always";
                "editor.autoClosingBrackets" = "always";
                "editor.inlineSuggest.enabled" = true;
                "editor.mouseWheelZoom" = true;
                "editor.inlineSuggest.syntaxHighlightingEnabled" = true;
                "editor.suggest.preview" = true;
                "editor.suggest.shareSuggestSelections" = true;

                "github.copilot.enable"."*" = true;
                "github.copilot.advanced".indentationMode."*" = true;
                "github.copilot.nextEditSuggestions.enabled" = true;

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

                #region Language Formatters
                "evenBetterToml.formatter.alignComments" = true;
                "evenBetterToml.formatter.alignEntries" = true;
                "evenBetterToml.formatter.allowedBlankLines" = 1;
                "evenBetterToml.formatter.arrayAutoCollapse" = true;
                "evenBetterToml.formatter.arrayAutoExpand" = true;
                "evenBetterToml.formatter.arrayTrailingComma" = true;
                "evenBetterToml.formatter.columnWidth" = 80;

                "markdown.validate.enabled" = true;
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

                "projectManager.git.baseFolders" = [
                  "${config.home.homeDirectory}/Projects"
                ];

                # Connecting to a NixOS or NuShell host breaks without this.
                "remote.SSH.permitPtyAllocation" = true;
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
                    "workbench.settings.applyToAllProfiles" = builtins.attrNames providedAttrs.userSettings ++ [
                      "workbench.colorTheme" # Managed by Stylix
                    ];
                  };
                }
              ];
          in
          {
            default = mkProfile {
              enableUpdateCheck = false;
              enableExtensionUpdateCheck = false;
            };

            jvm = lib.mkIf cfg.jvm.enable (mkProfile {

            });

            rust = lib.mkIf cfg.rust.enable (mkProfile {
              extensions = versionExtensions [
                "jscearcy.rust-doc-viewer"
                "dustypomerleau.rust-syntax"
                "rust-lang.rust-analyzer"
              ];
            });

            dotnet = lib.mkIf cfg.dotnet.enable (mkProfile {
              extensions = versionExtensions [
                "ms-dotnettools.csharp"
                "ms-dotnettools.csdevkit"
                "ms-dotnettools.vscode-dotnet-runtime"

                "ms-vscode.powershell"
                "pspester.pester-test"
                "ironmansoftware.powershellprotools"
                "tylerleonhardt.vscode-inline-values-powershell"
              ];

              userSettings = {
                # Required by ironmansoftware.powershellprotools
                "terminal.integrated.enablePersistentSessions" = false;
              };
            });

            python = lib.mkIf cfg.python.enable (mkProfile {
              extensions = versionExtensions [
                "ms-python.python"
                "ms-python.vscode-pylance"
                "ms-python.debugpy"
                "ms-python.black-formatter"
                "ms-python.isort"
                "ms-python.pylint"
                "ms-python.mypy-type-checker"
                "ms-python.gather"
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
    })

    (lib.mkIf (config ? stylix && config.stylix.enable) {
      stylix.targets.vscode.profileNames = profiles;
    })
  ];
}

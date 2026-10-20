{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkEnableOption
    ;

  cfg = config.purpose.development;

  languages = config.purpose.development.languages;

  rendered = import ./render.nix {
    inherit lib languages;
  };

  profiles = [
    "default"
    "rust"
    "jvm"
    "dotnet"
    "python"
    "work"
  ];
in
{
  options.purpose.development.editors.vscode = {
    enable = mkEnableOption "Enable VSCode" // {
      default = cfg.enable;
    };
  };

  config = mkMerge [
    (mkIf cfg.editors.vscode.enable {
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

                # LSP Servers

                # Formatters

                # Containers

                # AI
                "github.copilot-chat"

                # Other
                "formulahendry.code-runner"
                "markis.code-coverage"
                "vadimcn.vscode-lldb"
                "platformio.platformio-ide"

                # Bash Extensions
                "rogalmic.bash-debug"

                # Integrations
                "jjk.jjk"
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
                #endregion

                #region Language Formatters
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

                "gitlens.plusFeatures.enabled" = false;
                "gitlens.graph.layout" = "editor";
                "gitlens.launchpad.indicator.enabled" = false;
                "gitlens.cloudPatches.enabled" = false;
                "gitlens.views.commits.showStashes" = true;
                "gitlens.views.repositories.showStashes" = true;

                "projectManager.git.baseFolders" = [
                  "${config.home.homeDirectory}/Projects"
                ];

                "todotree.ripgrep" = lib.getExe pkgs.ripgrep;

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
              extensions = versionExtensions (rendered.extensions "default");
              userSettings = rendered.settings "default";
            };

            jvm = mkIf cfg.languages.jvm.enable (mkProfile {
              extensions = versionExtensions (rendered.extensions "jvm");
              userSettings = rendered.settings "jvm";
            });

            rust = mkIf cfg.languages.rust.enable (mkProfile {
              extensions = versionExtensions (rendered.extensions "rust");
              userSettings = rendered.settings "rust";
            });

            dotnet = mkIf (cfg.languages.csharp.enable || cfg.languages.powershell.enable) (mkProfile {
              extensions = versionExtensions (rendered.extensions "dotnet");
              userSettings = rendered.settings "dotnet";
            });

            python = mkIf cfg.languages.python.enable (mkProfile {
              extensions = versionExtensions (rendered.extensions "python");
              userSettings = rendered.settings "python";
            });

            work = mkProfile {
              extensions = versionExtensions [
                "teamsdevapp.ms-teams-vscode-extension"
              ];
            };
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

    (mkIf (config ? stylix && config.stylix.enable) {
      stylix.targets.vscode.profileNames = profiles;
    })
  ];
}

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
    programs.vscode = {
      enable = true;

      # Allows Settings Sync to work;
      mutableExtensionsDir = true;

      # Disable update checks
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;

      # TODO -> Add [aaron-bond.better-comments, wayou.vscode-todo-highlight]
      # forVSCodeVersion package.version
      extensions =
        let
          extensions = inputs.vscode-extensions.extensions.${pkgs.stdenv.system};
          versionExtensions = extensions.forVSCodeVersion config.programs.vscode.package.version;

          plugins = (import ./extensions.nix) { inherit pkgs lib; };
        in
        with extensions.vscode-marketplace;
        [
          # Theme & Looks
          plugins.zhuangtongfa.material-theme
          plugins.pkief.material-icon-theme

          # Workspaces & Projects
          plugins.mkhl.direnv
          plugins.editorconfig.editorconfig
          plugins.alefragnani.project-manager
          plugins.ms-vscode-remote.remote-ssh

          # Sidebar Additions
          plugins.gruntfuggly.todo-tree
          plugins.eamodio.gitlens

          # Language Support
          redhat.vscode-xml
          redhat.vscode-yaml
          plugins.tamasfe.even-better-toml
          plugins.matthewpi.caddyfile-support
          plugins.coolbear.systemd-unit-file
          plugins.hashicorp.terraform
          plugins.bierner.markdown-preview-github-styles
          plugins.ruschaaf.extended-embedded-languages

          # LSP Servers
          plugins.jnoortheen.nix-ide
          plugins.ms-vscode.powershell

          # Formatters
          plugins.esbenp.prettier-vscode

          # Containers
          plugins.ms-azuretools.vscode-docker

          # AI
          plugins.github.copilot
          plugins.github.copilot-chat

          # Other
          plugins.formulahendry.code-runner
          # platformio.platformio-ide

          # Bash Extensions
          plugins.rogalmic.bash-debug
          plugins.foxundermoon.shell-format

          # Integrations
          plugins.github.vscode-github-actions
          plugins.github.vscode-pull-request-github
        ]
        ++ (lib.optionals cfg.python.enable (
          with versionExtensions.vscode-marketplace.ms-python;
          [
            python
            vscode-pylance
            debugpy
            black-formatter
            isort
            pylint
            mypy-type-checker
            gather
          ]
        ))
        ++ (lib.optionals cfg.rust.enable (
          with versionExtensions.vscode-marketplace;
          [
            vadimcn.vscode-lldb
            fill-labs.dependi
            jscearcy.rust-doc-viewer
            dustypomerleau.rust-syntax
            rust-lang.rust-analyzer
          ]
        ))
        ++ (lib.optionals cfg.jvm.enable (
          with extensions.open-vscx;
          [

          ]
        ));

      userSettings = {
        "workbench.iconTheme" = "material-icon-theme";
        "workbench.startupEditor" = "none";

        "window.zoomLevel" = 3;
        "window.titleBarStyle" = "custom";

        "settingsSync.ignoredExtensions" = [ "*" ];

        "editor.formatOnSave" = true;
        "editor.autoClosingQuotes" = "always";
        "editor.autoClosingBrackets" = "always";
        "editor.inlineSuggest.enabled" = true;
        "editor.mouseWheelZoom" = true;

        "diffEditor.ignoreTrimWhitespace" = false;

        "extensions.ignoreRecommendations" = true;

        "github.copilot.enable"."*" = true;
        "github.copilot.advanced".indentationMode."*" = true;

        "files.autoSave" = "afterDelay";
        "files.eol" = "\n";

        "git.autofetch" = true;
        "git.confirmSync" = false;
        "git.allowForcePush" = true;
        "git.allowNoVerifyCommit" = true;
        "git.autoStash" = true;
        "git.blame.statusBarItem.enabled" = true;

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

        "direnv.restart.automatic" = true;
        "direnv.status.showChangesCount" = true;

        "caddyfile.executable" = "${lib.getExe pkgs.caddy}";

        "redhat.telemetry.enabled" = false;

        "gitlens.showWhatsNewAfterUpgrades" = false;
        "gitlens.plusFeatures.enabled" = false;
        "gitlens.graph.layout" = "editor";
        "gitlens.launchpad.indicator.enabled" = false;
        "gitlens.cloudPatches.enabled" = false;
        "gitlens.views.commits.showStashes" = true;
        "gitlens.telemetry.enabled" = false;
        "gitlens.views.repositories.showStashes" = true;

        # "platformio-ide.customPATH" = "${pkgs.platformio}/bin/platformio";
        # "platformio-ide.useBuiltinPython" = false;
        # "platformio-ide.useBuiltinPIOCore" = false;
        # "platformio-ide.pioHomeServerHttpPort" = 8008;
      };

      # keybindings = {
      #   a = builtins.fromTOML "[}";
      # };
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

{ inputs, config, pkgs, lib, ... }: with lib; let
  cfg = config.purpose.development;
in
{
  imports = [
    ./rust.nix
    ./jvm.nix
  ];

  options.purpose.development = {
    enable = mkEnableOption "development";

    vscode = {
      enable = mkEnableOption "Enable VSCode" // { default = true; };
    };

    python = {
      enable = mkEnableOption "Enable Python Development";
    };
  };

  config = mkIf cfg.enable {
    programs.vscode = mkIf cfg.vscode.enable {
      enable = true;
      package = pkgs.unstable.vscode;

      # Allows Settings Sync to work;
      # TODO -> Maybe replace with sync from nextcloud?
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
        in
        with extensions.vscode-marketplace; [
          # Theme & Looks
          zhuangtongfa.material-theme
          pkief.material-icon-theme

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
          redhat.vscode-yaml
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
        ] ++ (optionals cfg.python.enable (with versionExtensions.vscode-marketplace.ms-python; [
          python
          vscode-pylance
          debugpy
          black-formatter
          isort
          pylint
          mypy-type-checker
          gather
        ])) ++ (optionals cfg.rust.enable (with versionExtensions.vscode-marketplace; [
          vadimcn.vscode-lldb
          fill-labs.dependi
          jscearcy.rust-doc-viewer
          dustypomerleau.rust-syntax
          rust-lang.rust-analyzer
        ])) ++ (optionals cfg.jvm.enable (with extensions.open-vscx; [

        ]));

      userSettings = {
        "workbench.iconTheme" = "material-icon-theme";
        "workbench.colorTheme" = "One Dark Pro Mix";
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

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${lib.getExe pkgs.nil}";
        "nix.serverSettings" = {
          nil = {
            diagnostics = {
              ignored = [ ];
            };
            formatting = {
              command = [ "${pkgs.unstable.nixpkgs-fmt}/bin/nixpkgs-fmt" ];
            };
          };

          nixd = {
            formatting.command = "${pkgs.unstable.nixpkgs-fmt}/bin/nixpkgs-fmt";
            eval = {
              enable = true;
              targets = {
                args = [ "-f" "default.nix" ];
                installable = "";
              };
            };
            options = {
              enable = true;
              targets = {
                args = [ "-f" "default.nix" ];
                installable = "";
                # installable = "/flakeref#nixosConfigurations.nixe.options";
              };
            };
          };
        };

        "direnv.restart.automatic" = true;
        "direnv.status.showChangesCount" = true;

        "caddyfile.executable" = "${pkgs.unstable.caddy}/bin/caddy";

        "redhat.telemetry.enabled" = false;

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
      text = /*json*/''
        {
          "enable-crash-reporter": false,
          "password-store": "gnome-libsecret"
        }
      '';
    };

    user.persistence.directories = [
      "Projects"

      # VSCode
      ".config/Code/User/"

      # JetBrains IDEs
      ".local/share/JetBrains"
      ".cache/JetBrains" # TODO :: use version from pkg to limit further
      ".config/JetBrains" # Needed?
    ];
  };
}

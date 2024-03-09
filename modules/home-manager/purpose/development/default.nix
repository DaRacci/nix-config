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

    python = {
      enable = mkEnableOption "Enable Python Development";
    };
  };

  config = mkIf cfg.enable {
    programs.vscode = rec {
      enable = true;
      package = pkgs.unstable.vscode;

      # Allows Settings Sync to work;
      # TODO -> Maybe replace with sync from nextcloud?
      mutableExtensionsDir = true;

      # Disable update checks
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;

      # TODO -> Add [aaron-bond.better-comments, github.copilot-labs, wayou.vscode-todo-highlight]
      # forVSCodeVersion package.version
      extensions = let extensions = inputs.vscode-extensions.extensions.${pkgs.stdenv.system}; in with extensions.vscode-marketplace; [
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

        # Language Support
        redhat.vscode-xml
        redhat.vscode-yaml
        tamasfe.even-better-toml
        matthewpi.caddyfile-support
        coolbear.systemd-unit-file

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
        formulahendry.auto-close-tag
        formulahendry.auto-rename-tag

        # Bash Extensions
        rogalmic.bash-debug
        foxundermoon.shell-format

        # Integrations
        github.vscode-github-actions
      ] ++ (optionals (cfg.python.enable) (with extensions.vscode-marketplace.ms-python; [
        python
        vscode-pylance
        debugpy
        black-formatter
        isort
        pylint
        mypy-type-checker
        gather
      ])) ++ (optionals (cfg.rust.enable) (with extensions.vscode-marketplace; [
        vadimcn.vscode-lldb
        serayuzgur.crates
        jscearcy.rust-doc-viewer
        dustypomerleau.rust-syntax
        rust-lang.rust-analyzer
      ])) ++ (optionals (cfg.jvm.enable) (with extensions.open-vscx; [

      ]));

      userSettings = {
        workbench.iconTheme = "material-icon-theme";
        workbench.colorTheme = "One Dark Pro Mix";
        workbench.startupEditor = "none";

        "window.zoomLevel" = 3;

        # TODO -> Use reference to package for this
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Symbols Nerd Font Mono', 'Material Icons Outlined'";
        "editor.fontSize" = 16;
        "editor.fontLigatures" = true;
        "editor.formatOnSave" = true;
        "editor.autoClosingQuotes" = "always";
        "editor.autoClosingBrackets" = "always";
        "editor.inlineSuggestenabled" = true;
        "editor.mouseWheelZoom" = true;

        "diffEditor.ignoreTrimWhitespace" = false;

        "github.copilot.enable"."*" = true;
        "github.copilot.advanced.indentationMode"."*" = true;

        "files.autoSave" = "afterDelay";
        "files.eol" = "\n";

        "git.autofetch" = true;

        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "${pkgs.unstable.nixd}/bin/nixd";
        "nix.serverSettings" = {
          nixd = {
            formatting.command = "${pkgs.unstable.nixpkgs-fmt}/bin/nixpkgs-fmt";
            options = {
              enable = true;
              targets = {
                args = [ "-f" "default.nix" ];
                installable = "<flakeref>#nixosConfigurations.nixe.options";
              };
            };
          };
        };

        "caddyfile.executable" = "${pkgs.unstable.caddy}/bin/caddy";

        "redhat.telemetry.enabled" = false;
      };

      # keybindings = {
      #   a = builtins.fromTOML "[}";
      # };
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

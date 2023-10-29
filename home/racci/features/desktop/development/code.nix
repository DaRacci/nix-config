{ config, lib, pkgs, persistenceDirectory, hasPersistence, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;

    # Allows Settings Sync to work;
    # TODO -> Maybe replace with sync from nextcloud?
    mutableExtensionsDir = true;

    # Disable update checks
    enableExtensionUpdateCheck = true;
    enableUpdateCheck = false;

    # TODO -> Add [aaron-bond.better-comments, github.copilot-labs, wayou.vscode-todo-highlight]
    extensions = with pkgs.unstable.vscode-extensions; [
      # Theme & Looks
      zhuangtongfa.material-theme
      pkief.material-icon-theme

      # Workspaces & Projects
      editorconfig.editorconfig
      alefragnani.project-manager
      ms-vscode-remote.remote-ssh

      # Basic File Formats
      redhat.vscode-xml
      redhat.vscode-yaml
      tamasfe.even-better-toml

      # Program Specific Formats
      matthewpi.caddyfile-support

      # Linux Specific Formats
      coolbear.systemd-unit-file

      # Lanauge + LSP Support
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

      # Integrations
      github.vscode-github-actions
    ];

    userSettings = {
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.colorTheme" = "One Dark Pro Mix";
      "workbench.startupEditor" = "none";

      "window.zoomLevel" = 3;

      # TODO -> Use reference to package for this
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Symbols Nerd Font Mono', 'Material Icons Outlined'";
      "editor.fontSize" = 16;
      "editor.fontLigatures" = true;
      "editor.formatOnSave" = true;
      "editor.autoClosingQuotes" = "always";
      "editor.autoClosingBrackets" = "always";
      "editor.inlineSuggest.enabled" = true;
      "editor.mouseWheelZoom" = true;

      "github.copilot.enable"."*" = true;
      "github.copilot.advanced"."indentationMode"."*" = true;

      "files.autoSave" = "afterDelay";

      "git.autofetch" = true;

      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "${pkgs.unstable.nil}/bin/nil";
      "nix.serverSettings".nil.formatting.command = [ "${pkgs.unstable.nixpkgs-fmt}/bin/nixpkgs-fmt" ];

      "caddyfile.executable" = "${pkgs.unstable.caddy}/bin/caddy";

      "redhat.telemetry.enabled" = false;
    };
  };
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/Code/User/"
  ];
}

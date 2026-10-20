{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
in
import ./mkLanguage.nix {
  inherit config pkgs lib;
  name = "common";

  defaultEnable = true;

  lsp = [
    {
      name = "marksman";
      package = pkgs.marksman;
      args = [ "server" ];
      filetypes = [
        ".md"
        ".mdx"
      ];
      languages = [ "Markdown" ];
      editors.helix.languages = [ "markdown" ];
    }
    {
      name = "yaml-language-server";
      package = pkgs.yaml-language-server;
      args = [ "--stdio" ];
      filetypes = [
        ".yaml"
        ".yml"
      ];
      languages = [ "YAML" ];
      editors.helix.languages = [ "yaml" ];
    }
    {
      name = "vscode-json-language-server";
      package = pkgs.vscode-langservers-extracted;
      binary = "vscode-json-language-server";
      args = [ "--stdio" ];
      filetypes = [
        ".json"
        ".jsonc"
      ];
      languages = [ "JSON" ];
      editors.helix.languages = [ "json" ];
    }
    {
      name = "vscode-css-language-server";
      package = pkgs.vscode-langservers-extracted;
      binary = "vscode-css-language-server";
      args = [ "--stdio" ];
      filetypes = [
        ".css"
        ".scss"
        ".less"
      ];
      languages = [ "CSS" ];
      editors.helix.languages = [ "css" ];
    }
    {
      name = "vscode-html-language-server";
      package = pkgs.vscode-langservers-extracted;
      binary = "vscode-html-language-server";
      args = [ "--stdio" ];
      filetypes = [
        ".html"
        ".htm"
      ];
      languages = [ "HTML" ];
      editors.helix.languages = [ "html" ];
    }
    {
      name = "taplo";
      package = pkgs.taplo;
      args = [
        "lsp"
        "stdio"
      ];
      filetypes = [ ".toml" ];
      languages = [ "TOML" ];
      editors.helix.languages = [ "toml" ];
    }
    {
      name = "bash-language-server";
      package = pkgs.bash-language-server;
      args = [ "start" ];
      filetypes = [
        ".sh"
        ".bash"
        ".zsh"
      ];
      languages = [ "Shell Script" ];
      editors.helix.languages = [ "bash" ];
    }
    {
      name = "dockerfile-language-server";
      package = pkgs.dockerfile-language-server;
      args = [ "--stdio" ];
      filetypes = [
        "Dockerfile"
        "Dockerfile.*"
        "*.dockerfile"
      ];
      languages = [ "Dockerfile" ];
      editors.helix.languages = [ "dockerfile" ];
    }
    {
      name = "docker-compose";
      package = pkgs.docker-compose-language-service;
      binary = "docker-compose-langserver";
      args = [ "--stdio" ];
      filetypes = [
        "docker-compose.yml"
        "docker-compose.yaml"
        "compose.yml"
        "compose.yaml"
      ];
      languages = [ "Docker Compose" ];
      editors.helix.languages = [ "yaml" ];
    }
    {
      name = "sqls";
      package = pkgs.sqls;
      filetypes = [ ".sql" ];
      languages = [ "SQL" ];
      editors.helix.languages = [ "sql" ];
    }
    {
      name = "terraform-ls";
      package = pkgs.terraform-ls;
      args = [ "serve" ];
      filetypes = [
        ".tf"
        ".tfvars"
      ];
      languages = [ "Terraform" ];
      editors.helix.languages = [ "hcl" ];
    }
    {
      name = "lemminx";
      package = pkgs.lemminx;
      filetypes = [ ".xml" ];
      languages = [ "XML" ];
      editors.helix.languages = [ "xml" ];
    }
    {
      name = "autocorrect";
      package = pkgs.autocorrect;
      args = [ "server" ];
      filetypes = [
        ".md"
        ".txt"
      ];
      languages = [
        "Markdown"
        "Text"
      ];
      editors.helix.languages = [ "markdown" ];
    }
  ];

  formatters = [
    {
      name = "taplo";
      package = pkgs.taplo;
      args = [
        "format"
        "-"
      ];
      filetypes = [ ".toml" ];
      languages = [ "TOML" ];
      editors.helix.languages = [ "toml" ];
      editors.opencode.command = [
        "taplo"
        "format"
        "$FILE"
      ];
    }
    {
      name = "shfmt";
      package = pkgs.shfmt;
      args = [ "-" ];
      filetypes = [
        ".sh"
        ".bash"
        ".zsh"
      ];
      languages = [ "Shell Script" ];
      editors.helix.languages = [ "bash" ];
      editors.opencode.command = [
        "shfmt"
        "-w"
        "$FILE"
      ];
    }
  ];

  extraPackages = [
    pkgs.caddy
    pkgs.prettier
    pkgs.shellcheck
  ];

  editors = {
    zed = {
      extensions = [
        "docker-compose"
        "dockerfile"
        "editorconfig"
        "ini"
        "json"
        "markdown"
        "sql"
        "terraform"
        "toml"
        "xml"
        "yaml"
      ];
      languages = [
        "JSON"
        "YAML"
        "TOML"
        "Markdown"
        "CSS"
        "HTML"
        "XML"
        "SQL"
        "Terraform"
        "Dockerfile"
        "Docker Compose"
        "Shell Script"
      ];
    };

    vscode = {
      profile = "default";
      extensions = [
        "bierner.markdown-preview-github-styles"
        "coolbear.systemd-unit-file"
        "esbenp.prettier-vscode"
        "foxundermoon.shell-format"
        "hashicorp.terraform"
        "jamief.vscode-ssh-config-enhanced"
        "keesschollaart.vscode-home-assistant"
        "matthewpi.caddyfile-support"
        "ms-azuretools.vscode-docker"
        "owensimon.combinatorc"
        "redhat.vscode-xml"
        "redhat.vscode-yaml"
        "rogalmic.bash-debug"
        "ruschaaf.extended-embedded-languages"
        "tamasfe.even-better-toml"
      ];
      settings = {
        "caddyfile.executable" = getExe pkgs.caddy;

        "evenBetterToml.formatter.alignComments" = true;
        "evenBetterToml.formatter.alignEntries" = true;
        "evenBetterToml.formatter.allowedBlankLines" = 1;
        "evenBetterToml.formatter.arrayAutoCollapse" = true;
        "evenBetterToml.formatter.arrayAutoExpand" = true;
        "evenBetterToml.formatter.arrayTrailingComma" = true;
        "evenBetterToml.formatter.columnWidth" = 80;

        "[jsonc]" = {
          "editor.defaultFormatter" = "vscode.json-language-features";
        };

        "markdown.validate.enabled" = true;
      };
    };
  };
}

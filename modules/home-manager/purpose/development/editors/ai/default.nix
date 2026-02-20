{
  osConfig,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development.editors.ai;
in
{
  options.purpose.development.editors.ai = {
    enable = lib.mkEnableOption "Enable AI Tools & Assistants";
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensure-aifs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $VERBOSE_ARG \
        "${config.home.homeDirectory}/Projects/AIFS";
    '';

    programs = {
      zed-editor.userSettings = {
        agent_servers = {
          OpenCode = {
            command = lib.getExe pkgs.opencode;
            args = [ "acp" ];
          };
        };
      };

      opencode = {
        enable = true;
        settings = {
          "$schema" = "https://opencode.ai/config.json";
          share = "disabled";

          plugin = [
            "jj-opencode"
            "oh-my-opencode@latest"
            "@simonwjackson/opencode-direnv"
            "opencode-plugin-openspec"
            "@plannotator/opencode@latest"
            "@mohak34/opencode-notifier@latest"
          ];

          formatter = {
            nixfmt = {
              command = [
                "nixfmt"
                "$FILE"
              ];
              extensions = [ ".nix" ];
            };
          };

          lsp = {
            nixd = {
              command = [
                "${lib.getExe pkgs.nixd}"
                "--semantic-tokens"
                "--inlay-hints"
              ]
              ++ (lib.optionals (osConfig != null) [
                "--nixos-options-expr (builtins.getFlake (builtins.toString ./.)).nixosConfigurations.(${osConfig.host.name}).options"
              ]);
              extensions = [ ".nix" ];
            };
            nil = {
              command = [ "${lib.getExe pkgs.nil}" ];
              extensions = [ ".nix" ];
            };
          };

          permission = {
            edit = "allow";
            bash = {
              "*" = "ask";
              "grep *" = "allow";
              "rm *" = "deny";
              "git *" = "allow";
              "sops encrypt" = "allow";
              "sops -e" = "allow";
              "sops --encrypt" = "allow";
              "nix build *" = "allow";
              "nix flake *" = "allow";
              "nix fmt *" = "allow";
            };
            webfetch = "allow";
          };

          # Duplicated from hosts/server/nixai/backend.nix since no support for openai.json tool servers
          mcp = {
            nixos = {
              type = "local";
              command = [
                (lib.getExe' pkgs.uv "uvx")
                "mcp-nixos"
              ];
              enabled = true;
            };
            context7 = {
              type = "local";
              command = [
                (lib.getExe' pkgs.nodejs "npx")
                "-y"
                "@upstash/context7-mcp"
              ];
              enabled = true;
            };
          };
        };
      };
    };

    xdg.configFile = {
      "opencode/oh-my-opencode.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";

        agents = {
          sisyphus.model = "github-copilot/claude-opus-4.6";
          atlas.model = "github-copilot/gpt-5.2-codex";
          prometheus.model = "github-copilot/gpt-5.2-codex";

          oracle.model = "github-copilot/gpt-5.2";
          librarian.model = "opencode/glm-5-free";
          explore.model = "github-copilot/grok-code-fast-1";
          frontend-ui-ux-engineer.model = "github-copilot/gemini-3.1-pro-preview";
          document-writer.model = "github-copilot/gemini-3-flash-preview";
          multimodal-looker.model = "github-copilot/gemini-3-flash-preview";
        };
      };

      "opencode/opencode-notifier.json".text = builtins.toJSON {
        notification = true;
        showIcon = true;
        showProjectName = true;
        showSessionTitle = true;
        sound = false;
        timeout = 5;
      };
    };

    user.persistence.directories = [
      ".local/share/opencode"
      ".local/state/opencode"
    ];
  };
}

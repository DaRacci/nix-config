{
  osConfig,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.purpose.development.editors.ai;
in
{
  options.purpose.development.editors.ai = {
    enable = mkEnableOption "Enable AI Tools & Assistants";
  };

  config = mkIf cfg.enable {
    home.activation.ensure-aifs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $VERBOSE_ARG \
        "${config.home.homeDirectory}/Projects/AIFS";
    '';

    programs = {
      git.ignores = [
        ".workspace"
        ".sisyphus"
      ];

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
              "echo *" = "allow";
              "exit *" = "allow";
              "find *" = "allow";
              "git *" = "allow";
              "grep *" = "allow";
              "head *" = "allow";
              "jj diff *" = "allow";
              "jj log *" = "allow";
              "jj status *" = "allow";
              "ls *" = "allow";
              "mkdir *" = "allow";
              "nix build *" = "allow";
              "nix flake *" = "allow";
              "nix fmt *" = "allow";
              "printf *" = "allow";
              "rm *" = "deny";
              "sops --encrypt" = "allow";
              "sops -e" = "allow";
              "sops encrypt" = "allow";
              "tail *" = "allow";
              "touch *" = "allow";
              "wc *" = "allow";
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
          };
        };
      };
    };

    xdg.configFile = {
      "opencode/oh-my-opencode.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";

        disabled_skills = [
          "playwright"
          "git-master"
        ];

        agents = {
          sisyphus.model = "github-copilot/claude-opus-4.6";
          atlas.model = "github-copilot/gpt-5.2-codex";
          prometheus.model = "github-copilot/gpt-5.2-codex";

          hephaestus.model = "github-copilot/gpt-5.2-codex";
          oracle.model = "github-copilot/gpt-5.2";
          momus.model = "github-copilot/gpt-5.2";
          metis.model = "github-copilot/claude-opus-4.6";

          explore.model = "github-copilot/grok-code-fast-1";
          librarian.model = "github-copilot/gpt-5-mini";
          multimodal-looker.model = "github-copilot/gemini-3-flash-preview";
        };

        categories = {
          quick.model = "github-copilot/claude-haiku-4.5";
          deep = {
            model = "github-copilot/gpt-5.2-codex";
            variant = "medium";
          };
          ultrabrain = {
            model = "github-copilot/gpt-5.2-codex";
            variant = "xhigh";
          };
          artistry.model = "github-copilot/gemini-3.1-pro-preview";

          unspecified-low.model = "github-copilot/claude-sonnet-4.6";
          unspecified-high = {
            model = "github-copilot/claude-opus-4.6";
            variant = "max";
          };
          writing.model = "github-copilot/gemini-3-flash-preview";
          visual-engineering.model = "github-copilot/gemini-3.1-pro-preview";
        };

        background_task = {
          modelConcurrency = {
            "github-copilot/gpt-5.2-mini" = 20;
            "github-copilot/claude-opus-4.6" = 2;
          };
        };

        disabled_hooks = [
          "prometheus-md-only" # Try to allow prometheus to use openspec instead.
        ];
      };

      "opencode/opencode-notifier.json".text = builtins.toJSON {
        notification = true;
        showIcon = true;
        showProjectName = true;
        showSessionTitle = false;
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

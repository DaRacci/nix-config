{
  self,
  osConfig,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionals
    types
    ;
  inherit (types) listOf bool str;

  cfg = config.purpose.development.editors.ai;

  defaultSkills =
    builtins.readDir ./skills |> builtins.attrNames |> map (skillName: "${self}/skills/${skillName}");
in
{
  options.purpose.development.editors.ai = {
    enable = mkEnableOption "Enable AI Tools & Assistants";

    includeDefaults = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether to include the default set of agents and skills provided by this module.
        This includes the agents and skills defined in the `./agents` and `./skills` directories of this module.

        Disabling this will result in a minimal setup with only the base configuration for OpenCode and no pre-registered agents or skills.
      '';
    };

    skills = mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        List of additional AI skills to add to the global registry.
        These should be paths to a skill directory, this could be through
        a flake input or a path in the flake.

        These skills will be installed to ~/.agents/skills and will be available to
        all agents that support the skill system, such as Claude and OpenCode.
      '';
      example = ''
        [
          ''${inputs.my-skill-repo}/skills/my-skill
          ''${self}/skills/another-skill
        ]
      '';
    };
  };

  config = mkIf cfg.enable {
    home = {
      sessionVariables = {
        OMO_SEND_ANONYMOUS_TELEMETRY = "0";
      };

      activation.ensure-aifs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p $VERBOSE_ARG \
          "${config.home.homeDirectory}/Projects/AIFS";
      '';
    };

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
            "oh-my-openagent@latest"
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
            # Nix
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

            # Configuration formats
            marksman = {
              command = [
                "${lib.getExe pkgs.marksman}"
                "server"
              ];
              extensions = [
                ".md"
                ".mdx"
              ];
            };
            yaml-language-server = {
              command = [
                "${lib.getExe pkgs.yaml-language-server}"
                "--stdio"
              ];
              extensions = [
                ".yaml"
                ".yml"
              ];
            };
            json-language-server = {
              command = [
                "${lib.getExe' pkgs.vscode-langservers-extracted "vscode-json-language-server"}"
                "--stdio"
              ];
              extensions = [
                ".json"
                ".jsonc"
              ];
            };
            css-language-server = {
              command = [
                "${lib.getExe' pkgs.vscode-langservers-extracted "vscode-css-language-server"}"
                "--stdio"
              ];
              extensions = [
                ".css"
                ".scss"
                ".less"
              ];
            };
            html-language-server = {
              command = [
                "${lib.getExe' pkgs.vscode-langservers-extracted "vscode-html-language-server"}"
                "--stdio"
              ];
              extensions = [
                ".html"
                ".htm"
              ];
            };
            taplo = {
              command = [
                "${lib.getExe pkgs.taplo}"
                "lsp"
                "stdio"
              ];
              extensions = [ ".toml" ];
            };

            # Programming languages
            rust-analyzer = {
              command = [ "${lib.getExe pkgs.rust-analyzer}" ];
              extensions = [ ".rs" ];
            };
            gopls = {
              command = [ "${lib.getExe pkgs.gopls}" ];
              extensions = [ ".go" ];
            };
            pyright = {
              command = [
                "${lib.getExe pkgs.pyright}"
                "--stdio"
              ];
              extensions = [ ".py" ];
            };
            typescript-language-server = {
              command = [
                "${lib.getExe pkgs.typescript-language-server}"
                "--stdio"
              ];
              extensions = [
                ".ts"
                ".tsx"
                ".js"
                ".jsx"
                ".mjs"
                ".cjs"
              ];
            };
            bash-language-server = {
              command = [
                "${lib.getExe pkgs.bash-language-server}"
                "start"
              ];
              extensions = [
                ".sh"
                ".bash"
                ".zsh"
              ];
            };
            lua-language-server = {
              command = [ "${lib.getExe pkgs.lua-language-server}" ];
              extensions = [ ".lua" ];
            };
            nushell = {
              command = [
                "${lib.getExe pkgs.nushell}"
                "--lsp"
              ];
              extensions = [ ".nu" ];
            };
            powershell-editor-services = {
              command = [ "${pkgs.powershell-editor-services}/bin/pwsh-es" ];
              extensions = [
                ".ps1"
                ".psm1"
                ".psd1"
              ];
            };
            dockerfile-language-server = {
              command = [
                "${lib.getExe pkgs.dockerfile-language-server}"
                "--stdio"
              ];
              extensions = [ "Dockerfile" ];
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
              "nix eval *" = "allow";
              "nix-instantiate *" = "allow";
              "printf *" = "allow";
              "rm *" = "deny";
              "sops --encrypt" = "allow";
              "sops -e" = "allow";
              "sops encrypt" = "allow";
              "tail *" = "allow";
              "touch *" = "allow";
              "wc *" = "allow";
              "openspec *" = "allow";
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
      "opencode/oh-my-openagent.json".text = builtins.toJSON {
        "$schema" =
          "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/master/assets/oh-my-opencode.schema.json";

        disabled_skills = [
          "playwright"
          "git-master"
        ];

        sisyphus = {
          tasks.enabled = true;
        };

        agents = {
          sisyphus.model = "github-copilot/claude-opus-4.6";
          atlas.model = "github-copilot/claude-sonnet-4.6";
          prometheus.model = "github-copilot/gpt-5.4";

          hephaestus.model = "github-copilot/gpt-5.4";
          oracle.model = "github-copilot/gpt-5.4";
          momus.model = "github-copilot/gpt-5.4";
          metis.model = "github-copilot/claude-opus-4.6";

          explore.model = "github-copilot/grok-code-fast-1";
          librarian.model = "github-copilot/gpt-5-mini";
          multimodal-looker.model = "github-copilot/gemini-3-flash-preview";
        };

        categories = {
          quick.model = "github-copilot/claude-haiku-4.5";
          deep = {
            model = "github-copilot/gpt-5.4";
            variant = "medium";
          };
          ultrabrain = {
            model = "github-copilot/gpt-5.4";
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
          defaultConcurrency = 5;
          modelConcurrency = {
            "github-copilot/grok-code-fast-1" = 10;
            "github-copilot/gpt-5-mini" = 20;
            "github-copilot/claude-opus-4.6" = 2;
          };
        };

        disabled_hooks = [
          "prometheus-md-only" # Try to allow prometheus to use openspec instead.
          "auto-update-checker"
          "startup-toast"
        ];

        hashline_edit = true;
        experimental = {
          task_system = true;
          dynamic_context_pruning.enabled = true;
        };
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

    home.file = mkMerge [
      (
        cfg.skills ++ optionals cfg.includeDefaults defaultSkills
        |> map (
          skillSource:
          nameValuePair ".agents/skills/${builtins.unsafeDiscardStringContext (baseNameOf skillSource)}" {
            source = skillSource;
          }
        )
        |> lib.listToAttrs
      )
    ];

    user.persistence.directories = [
      ".local/share/opencode"
      ".local/state/opencode"
    ];
  };
}

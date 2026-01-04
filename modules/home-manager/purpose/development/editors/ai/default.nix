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
            args = ["acp"];
          };
        };
      };

      opencode = {
        enable = true;
        settings = {
          "$schema" = "https://opencode.ai/config.json";
          share = "disabled";

          plugin = [ "oh-my-opencode" ];

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
            bash = "allow";
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

    xdg.configFile.".opencode/oh-my-opencode.json".text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
      auto_update = false;

      agents = {
        Sisyphus.model = "github-copilot/claude-opus-4.5";
      };
    };
  };
}

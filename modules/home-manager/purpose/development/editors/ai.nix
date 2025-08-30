{
  osConfig,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.development.ai;
in
{
  options.purpose.development.ai = {
    enable = lib.mkEnableOption "Enable AI Tools & Assistants";
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensure-aifs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p $VERBOSE_ARG \
        "${config.home.homeDirectory}/Projects/AIFS";
    '';

    programs = {
      opencode = {
        enable = true;
        config = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          share = "disabled";
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
  };
}

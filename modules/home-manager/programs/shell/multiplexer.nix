{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    literalExpression
    ;
  cfg = config.programSets.shell;
in
{
  options.programSets.shell.multiplexer = {
    enable = mkEnableOption "shell multiplexer" {
      default = config.programSets.shell.enable;
      defaultText = literalExpression "config.programSets.shell.enable";
    };
  };

  config = mkIf cfg.enable {
    programs = {
      zellij = {
        enable = true;
        settings = {
          show_release_notes = false;
          show_startup_tips = false;
          scroll_buffer_size = 25000;

          copy_command = "${lib.getExe' pkgs.wl-clipboard "wl-copy"}";
          copy_clipboard = "primary";

          ui = {
            pane_frames = {
              rounded_corners = true;
              hide_session_name = true;
            };
          };

          plugins = { };
          session_serialization = true;
          pane_viewport_serialization = true;
          scrollback_lines_to_serialize = 1000;
        };
      };

      nushell.extraConfig = lib.mkAfter ''
        if 'ZELLIJ' not-in ($env | columns) {
          zellij attach -c
        }
      '';
    };
  };
}

{ pkgs, lib, ... }:
{
  programs.zed-editor = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      nil
      shellcheck
      shfmt
      nerd-fonts.jetbrains-mono
      nixfmt-rfc-style
    ];

    userSettings = {
      ui_font_size = lib.mkForce 24;

      load_direnv = "shell_hook";

      assistant = {
        default_model = {
          provider = "ollama";
          model = "llama3.2:latest";
        };
        enabled = true;
        enable_experimental_live_diffs = true;
        version = "2";
      };

      lsp = {
        nil = {
          initialization_options = {
            formatting = {
              command = [ "nixfmt" ];
            };
          };
        };
      };

      autosave = "on_focus_change";
      auto_update = false;
      collaboration_panel = {
        button = false;
      };

      code_actions_on_format = { };

      chat_panel = { };

      features = { };

      file_finder = {
        modal_max_width = "medium";
      };

      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          show_commit_summary = true;
        };
      };

      gutter = { };

      indent_guides = { };

      inlay_hints = {
        enabled = true;
      };

      notification_panel = { };

      outline_panel = { };

      project_panel = { };

      relative_line_numbers = true;

      scrollbar = { };

      session = {
        restore_unsaved_buffers = true;
      };

      show_signature_help_after_edits = true;

      slash_commands = {
        cargo_workspace = {
          enabled = true;
        };
        docs = {
          enabled = true;
        };
      };

      task = {
        show_status_indicator = true;
      };

      unstable.ui_density = "comfortable";

      # buffer_font_family = "Zed Plex Mono";
      ui_font_family = lib.mkForce "Zed Plex Sans";

      tab_bar = {
        show_nav_history_buttons = false;
      };
      tabs = {
        file_icons = true;
        git_status = true;
      };

      terminal = {
        env = {
          # prevent highjacking the zellij session
          ZELLIJ = "";
        };
      };
    };

    # TODO - Define config here, until then doing it inside zed so i can quickly revise it.
  };

  user.persistence.directories = [
    ".config/zed"
    ".local/share/zed"
    ".config/github-copilot" # Contains the copilot auth token
  ];
}

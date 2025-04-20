{ pkgs, lib, ... }:
{
  programs.zed-editor = {
    enable = true;
    installRemoteServer = true;
    extraPackages = with pkgs; [
      # LSPs & other tools for zed
      autocorrect
      dockerfile-language-server-nodejs
      nixfmt-rfc-style
      nixd
      nil
      shellcheck
      shfmt

      libz
    ];

    extensions = [
      "toml"
      "dockerfile"
      "git-firefly"
      "tokyo-night"
      "terraform"
      "log"
      "docker-compose"
      "nix"
      "nu"
      "typos"
      "autocorrect"
      "cargo-tom"
      "cargo-appraiser"
      "colored-zed-icons-theme"
    ];

    # https://zed.dev/docs/configuring-zed
    userSettings = {
      theme = lib.mkForce "Tokyo Night";
      ui_font_size = lib.mkForce 24;
      hour_format = "hour24";
      load_direnv = "direct";
      autosave = "on_focus_change";
      auto_update = false;
      relative_line_numbers = false;
      restore_on_startup = "last_workspace";
      show_signature_help_after_edits = true;

      assistant = {
        enabled = true;
        version = "2";

        button = true;
        dock = "right";
        default_width = 640;
        default_height = 320;

        default_open_ai_model = null;
        enable_experimental_live_diffs = true;
        default_model = {
          provider = "copilot_chat";
          model = "o1-preview";
        };
      };

      icon_theme = {
        mode = "dark";
        dark = "Colored Zed Icons Theme Dark";
        light = "Colored Zed Icons Theme Light";
      };

      language_models = {
        copilot_chat = { };
        ollama = {
          api_url = "http://localhost:11434";
          available_models = [
            {
              display_name = "Llama 3.2";
              name = "llama3.2";
              keep_alive = "60s";
              max_tokens = 131072;
            }
          ];
        };
      };

      node = {
        path = lib.getExe pkgs.nodejs;
        npm_path = lib.getExe' pkgs.nodejs "npm";
      };

      edit_predictions = {
        disabled_globs = [
          "**/.env*"
          "**/*.pem"
          "**/*.key"
          "**/*.cert"
          "**/*.crt"
          "**/secrets.yml"
        ];
      };

      scrollbar = {
        show = "auto";
        cursors = true;
        git_diff = true;
        search_results = true;
        selected_symbol = true;
        diagnostics = "all";
        axes = {
          horizontal = true;
          vertical = true;
        };
      };

      tab_bar = {
        show = true;
        show_nav_history_buttons = true;
        show_tab_bar_buttons = true;
      };

      tabs = {
        close_position = "right";
        file_icons = true;
        git_status = true;
        activate_on_close = "history";
      };

      toolbar = {
        breadcrumbs = true;
        quick_actions = true;
      };

      languages = {
        Nix = {
          language_servers = [
            "nixd"
            "nil"
          ];
        };
      };

      lsp = {
        nil = {
          initialization_options = {
            formatting = {
              command = [ "nixfmt" ];
            };
          };
        };
        # TODO - Figure out how to do this without hard-coded paths.
        nixd.settings = {
          nixpkgs.expr = "import (builtins.getFlake \"/persist/nix-config\").inputs.nixpkgs { }";
          options = rec {
            nixos.expr = "(builtins.getFlake \"/persist/nix-config\").nixosConfigurations.nixe.options";
            home-manager.expr = "${nixos.expr}.home-manager.users.type.getSubOptions []";
            # home-manager.expr = "(builtins.getFlake \"/persist/nix-config\").homeConfigurations.racci.options";
            flake-parts.expr = "(builtins.getFlake \"/persist/nix-config\").debug.options";
            flake-parts2.expr = "(builtins.getFlake \"/persist/nix-config\").currentSystem.options";
          };
        };
      };

      file_scan_exclusions = [
        "**/.git"
        "**/.svn"
        "**/.hg"
        "**/.jj"
        "**/CVS"
        "**/.DS_Store"
        "**/Thumbs.db"
        "**/.classpath"
        "**/.settings"
        "**/.direnv"
        "**/.devenv"
      ];

      file_types = {

      };

      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          enabled = true;
          delay_ms = 500;
          show_commit_summary = true;
        };
      };

      gutter = { };

      indent_guides = {
        enabled = true;
        line_width = 1;
        active_line_width = 1;
        coloring = "indent_aware";
        background_coloring = "disabled";
      };

      inlay_hints = {
        enabled = false;
        show_type_hints = true;
        show_parameter_hints = true;
        show_other_hints = true;
        show_background = false;
        edit_debounce_ms = 700;
        scroll_debounce_ms = 50;
      };

      file_finder = {
        modal_max_width = "small";
      };

      outline_panel = { };

      project_panel = {
        button = true;
        default_width = 240;
        dock = "left";
        entry_spacing = "comfortable";
        file_icons = true;
        folder_icons = true;
        git_status = true;
        indent_size = 20;
        auto_reveal_entries = true;
        auto_fold_dirs = true;
        scrollbar = {
          show = "never";
        };
        indent_guides = {
          show = "always";
        };
      };

      # collaboration_panel.button = true;
      # chat_panel.button = "never";

      task = {
        show_status_indicator = true;
      };

      unstable.ui_density = "comfortable";

      ui_font_family = lib.mkForce "Zed Plex Sans";

      terminal = {
        env = {
          # prevent highjacking the zellij session
          ZELLIJ = "";
        };
      };
    };
  };

  user.persistence.directories = [
    ".config/zed"
    ".local/share/zed"
    ".config/github-copilot" # Contains the copilot auth token
  ];
}

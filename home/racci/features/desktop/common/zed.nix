{ pkgs, lib, ... }:
{
  programs.zed-editor = {
    enable = true;
    installRemoteServer = true;
    extraPackages = with pkgs; [
      # LSPs & other tools for zed
      autocorrect
      docker-compose-language-service
      dockerfile-language-server-nodejs
      nil
      nixd
      nixfmt
      powershell
      powershell-editor-services
      shellcheck
      shfmt

      libz
    ];

    extensions = [
      "autocorrect"
      "cargo-appraiser"
      "cargo-tom"
      "colored-zed-icons-theme"
      "docker-compose"
      "dockerfile"
      "git-firefly"
      "log"
      "nix"
      "nu"
      "terraform"
      "tokyo-night"
      "toml"
      "typos"
    ];

    # https://zed.dev/docs/configuring-zed
    userSettings = {
      theme = lib.mkForce "Tokyo Night";
      ui_font_size = lib.mkForce 24;
      load_direnv = "direct";
      autosave = "on_focus_change";
      auto_update = false;
      relative_line_numbers = false;
      restore_on_startup = "last_workspace";
      show_signature_help_after_edits = true;

      features = {
        edit_prediction_provider = "copilot";
      };

      agent = {
        enabled = true;

        button = true;
        dock = "right";
        default_width = 640;
        default_height = 320;

        default_model = {
          provider = "copilot_chat";
          model = "o4-mini";
        };

        default_profile = "write";
        profiles = {
          write = {
            name = "Write";
            tools = {
              open = true;
              create_directory = true;
              batch_tool = true;
              code_actions = true;
              code_symbols = true;
              contents = true;
              copy_path = true;
              create_file = true;
              delete_path = false;
              diagnostics = true;
              edit_file = true;
              fetch = true;
              list_directory = true;
              move_path = true;
              now = true;
              find_path = true;
              read_file = true;
              grep = true;
              rename = true;
              symbol_info = true;
              terminal = true;
              thinking = true;
              web_search = true;
            };

            enable_all_context_servers = true;
            context_servers = { };
          };
        };
      };

      icon_theme = {
        mode = "dark";
        dark = "Colored Zed Icons Theme Dark";
        light = "Colored Zed Icons Theme Light";
      };

      language_models = {
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
        mode = "eager";
        enabled_in_text_threads = true;
        disabled_globs = [
          "**/.env*"
          "**/*.pem"
          "**/*.key"
          "**/*.cert"
          "**/*.crt"
          "**/secrets.yml"
        ];
      };

      diagnostics = {
        include_warnings = false;
        inline = {
          enabled = true;
          update_debounce_ms = 150;
          padding = 4;
          min_column = 0;
          max_severity = null;
        };
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
          binary.path = lib.getExe pkgs.nil;
          initialization_options = {
            formatting = {
              command = [ "nixfmt" ];
            };
          };
        };
        # TODO - Figure out how to do this without hard-coded paths.
        nixd.settings = {
          binary.path = lib.getExe pkgs.nixd;
          nixpkgs.expr = "import (builtins.getFlake \"/persist/nix-config\").inputs.nixpkgs { }";
          options = rec {
            nixos.expr = "(builtins.getFlake \"/persist/nix-config\").nixosConfigurations.(builtins.replaceStrings [\"\\n\"] [\"\"] (builtins.readFile /etc/hostname)).options";
            home-manager.expr = "${nixos.expr}.home-manager.users.type.getSubOptions []";
            flake-parts.expr = "(builtins.getFlake \"/persist/nix-config\").debug.options";
            flake-parts2.expr = "(builtins.getFlake \"/persist/nix-config\").currentSystem.options";
          };
        };

        powershell-es = {
          binary.path = lib.getExe pkgs.powershell-editor-services;
        };

        docker-compose = {
          binary = {
            path = lib.getExe pkgs.docker-compose-language-service;
            arguments = [ "--stdio" ];
          };
        };

        autocorrect = {
          binary = {
            path = lib.getExe pkgs.autocorrect;
            arguments = [ "server" ];
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
        enabled = true;
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

      ui_font_family = lib.mkForce "Zed Plex Sans";

      terminal = {
        env = {
          # prevent highjacking the zellij session
          ZELLIJ = "";
        };
      };

      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      journal = {
        hour_format = "hour24";
      };
    };
  };

  user.persistence.directories = [
    ".config/zed"
    ".local/share/zed"
    ".config/github-copilot" # Contains the copilot auth token
  ];
}

{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  inherit (types)
    attrs
    bool
    listOf
    package
    str
    ;

  cfg = config.purpose.development.editors.zed;

  languages = config.purpose.development.languages;

  rendered = import ./render.nix {
    inherit lib languages;
  };

  defaultExtensions = [
    "autocorrect"
    "catppuccin-icons"
    "docker-compose"
    "dockerfile"
    "editorconfig"
    "git-firefly"
    "ini"
    "log"
    "nu"
    "qml"
    "terraform"
    "tokyo-night"
    "toml"
    "typos"
  ];

  defaultPackages = with pkgs; [
    autocorrect
    docker-compose-language-service
    dockerfile-language-server
    shellcheck
    shfmt

    libz
  ];

  # Ported from the previous user-level Zed configuration.
  # Values are plain defaults so they can be overridden via `userSettings`.
  defaultSettings = {
    theme = "Tokyo Night";
    ui_font_size = 24;
    load_direnv = "direct";
    autosave = "on_focus_change";
    auto_update = false;
    relative_line_numbers = "disabled";
    restore_on_startup = "last_workspace";
    show_signature_help_after_edits = true;

    agent = {
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

      thread_summary_model = {
        provider = "openrouter";
        model = "google/gemini-3.1-flash-lite";
      };
      subagent_model = {
        provider = "openrouter";
        model = "deepseek/deepseek-v4-flash";
      };
    };

    icon_theme = {
      mode = "dark";
      dark = "Catppuccin Latte";
      light = "Catppuccin Mocha";
    };

    language_models = {
      ollama.api_url = "http://localhost:11434";
    };

    node = {
      path = lib.getExe pkgs.nodejs;
      npm_path = lib.getExe' pkgs.nodejs "npm";
    };

    edit_predictions = {
      mode = "eager";
      disabled_globs = [
        "**/.env*"
        "**/*.pem"
        "**/*.key"
        "**/*.cert"
        "**/*.crt"
        "**/secrets.yml"
      ];
      ollama = {
        max_output_tokens = 256;
        prompt_format = "zeta2";
        api_url = "http://localhost:11434";
        model = "hf.co/bluevoid-pl/zeta2-GUFF:Q8_0";
      };
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

    git = {
      git_gutter = "tracked_files";
      gutter_debounce = 50;
      inline_blame = {
        enabled = true;
        delay_ms = 500;
        show_commit_summary = true;
      };
      worktree_directory = ".git/zed-worktrees";
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

    ui_font_family = ".ZedSans";

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
in
{
  options.purpose.development.editors.zed = {
    enable = mkEnableOption "Zed editor";

    installRemoteServer = mkOption {
      type = bool;
      default = true;
      description = "Install the Zed remote server binary so this machine can be a remote target.";
    };

    extensions = mkOption {
      type = listOf str;
      default = defaultExtensions;
      description = ''
        Zed extensions to install.
        Language modules contribute their own extensions automatically.
      '';
    };

    extraPackages = mkOption {
      type = listOf package;
      default = defaultPackages;
      description = ''
        Packages made available to Zed's wrapper PATH.
        Language modules contribute their own packages automatically.
      '';
    };

    userSettings = mkOption {
      type = attrs;
      default = { };
      description = ''
        Settings merged recursively over the module defaults.
        User values take precedence.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      installRemoteServer = cfg.installRemoteServer;
      extraPackages = cfg.extraPackages ++ rendered.extraPackages;
      extensions = cfg.extensions ++ rendered.extensions;
      userSettings = lib.foldl' lib.recursiveUpdate { } [
        defaultSettings
        rendered.userSettings
        cfg.userSettings
      ];
    };

    xdg.mimeApps.defaultApplicationPackages = [ pkgs.zed-editor ];

    user.persistence.directories = [
      ".config/zed"
      ".local/share/zed"
      ".config/github-copilot" # Contains the copilot auth token
    ];
  };
}

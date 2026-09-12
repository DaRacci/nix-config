_: {
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      encrypt_sensitive_data = true;
      developer.enabled = false;
      theme.enabled = false;
      power.enabled = false;

      scripts.preferences.customDirs = [ "/home/racci/.local/bin" ];

      clipboard = {
        preferences = {
          encryption = true;
          ignorePasswords = false;
        };
        entrypoints = {
          clear.enabled = false;
          clear-history.enabled = false;
        };
      };

      files.preferences = {
        autoIndexing = true;
        indexingPaths = [
          "/home/racci/Templates"
          "/home/racci/Pictures"
          "/home/racci/Documents"
          "/home/racci/Downloads"
          "/home/racci/Videos"
          "/home/racci/Projects"
          "/home/racci/Music"
        ];
        excludedIndexingPaths = [
          "/home/racci/Projects/Coding"
          "/home/racci/Projects/AIFS"
        ];
      };

      core.entrypoints = {
        about.enabled = false;
        documentation.enabled = false;
        manage-fallback.enabled = false;
        open-config-file.enabled = false;
        open-default-config.enabled = false;
        report-bug.enabled = false;
        sponsor.enabled = false;
      };

      browser-extension.entrypoints = {
        shortcut-active-tab.enabled = false;
      };

      system.entrypoints = {
        browse-apps.enabled = false;
        toggle-mute.enabled = false;
        volume-0.enabled = false;
        volume-25.enabled = false;
        volume-50.enabled = false;
        volume-75.enabled = false;
        volume-100.enabled = false;
        volume-up.enabled = false;
        volume-down.enabled = false;
      };

      providers = {
        "@Ninetonine/store.vicinae.searxng" = {
          preferences = {
            instance_domain = "https://search.racci.dev";
            languages = "en";
          };
        };

        "@knoopx/store.vicinae.nix".entrypoints = {
          flake-packages.alias = "nf";
          home-manager-options.alias = "hmo";
          options.alias = "no";
          packages.alias = "np";
          pull-requests.alias = "npr";
          protondb-search.alias = "pdb";
        };

        "@xwaleedahmad/store.vicinae.kde-connect".entrypoints = {
          send-clipboard.enabled = false;
        };
      };
    };
  };

  wayland.windowManager.hyprland.custom-settings.lua.luaModules = [ ../lua/vicinae.lua ];

  user.persistence.directories = [
    ".config/vicinae"
    ".local/share/vicinae"
  ];
}

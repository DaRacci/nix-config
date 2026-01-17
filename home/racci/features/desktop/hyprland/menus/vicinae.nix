{
  pkgs,
  ...
}:
{
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      font.normal.size = 12;

      providers = {
        "@khasbilegt/store.raycast.1password" = {
          preferences = {
            cliPath = "/run/wrappers/bin/op";
            zshPath = "${pkgs.zsh}";
          };
          entrypoints = {
            generate-password.alias = "gp";
            item-list.alias = "op";
          };
        };

        "@knoopx/store.vicinae.nix".entrypoints = {
          flake-packages.alias = "nf";
          home-manager-options.alias = "hmo";
          options.alias = "no";
          packages.alias = "np";
          pull-requests.alias = "npr";
        };

        clipboard.preferences = {
          encryption = true;
          ignorePasswords = false;
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
        developer.enabled = false;
        theme.enabled = false;
      };
    };
  };

  wayland.windowManager.hyprland.settings = {
    layerrule = [
      "blur on, match:namespace vicinae"
      "ignore_alpha 0, match:namespace vicinae"
    ];
    bind = [
      "CTRL_ALT, SPACE, exec, vicinae toggle"
      "SUPER, V, exec, vicinae vicinae://extensions/vicinae/clipboard/history"
    ];
  };

  user.persistence.directories = [
    ".config/vicinae"
    ".local/share/vicinae"
  ];
}

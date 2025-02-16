{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    _1password-gui
    _1password-cli
    bitwarden-desktop
    # bitwarden-cli
  ];

  user.persistence = {
    files = [ ".config/1Password/1password.sqlite" ];
    directories = [
      ".config/1Password/settings"
      ".config/Bitwarden"
      ".gnupg"
    ];
  };

  home.sessionVariables = {
    "SSH_AUTH_SOCK" = "${config.home.homeDirectory}/.1password/agent.sock";
  };

  user.autorun.services = {
    "1password" = {
      package = pkgs._1password-gui;
      extraArgs = [ "--silent" ];
    };
  };

  # https://developer.1password.com/docs/ssh/agent/config
  xdg.configFile."1Password/ssh/agent.toml".source = pkgs.writers.writeTOML "agent.toml" {
    ssh-keys = [ { vault = "Hosts & Users"; } ];
  };

  wayland.windowManager.hyprland = {
    custom-settings = {
      windowrule = [
        {
          matcher.title = "Quick Access — 1Password";
          rule = {
            pin = true;
            center = true;
            stayfocused = true;
          };
        }
      ];
    };

    settings.bind = [
      "CTRL_SHIFT,SPACE,exec,${lib.getExe pkgs._1password-gui} --quick-access"
    ];
  };

  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-rofi;
  };
}

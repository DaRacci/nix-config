# TODO :: Modularise
{ config, pkgs, lib, ... }: {
  home.packages = with pkgs; [
    gnome-secrets
    _1password-gui
    _1password
  ];

  user.persistence = {
    files = [ ".config/1Password/1password.sqlite" ];
    directories = [ ".config/1Password/settings" ];
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
    ssh-keys = [
      {
        vault = "Hosts & Users"
      }
    ];
  };
}

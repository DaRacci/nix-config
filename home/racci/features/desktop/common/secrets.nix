{ config, pkgs, ... }: {
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
}

{
  osConfig ? null,
  config,
  lib,
  ...
}:
lib.mkIf (osConfig == null || osConfig.users.users.${config.home.username}.shell.pname == "fish") {
  programs.fish = {
    enable = true;
  };

  user.persistence.files = [ ".local/share/fish/fish_history" ];
}

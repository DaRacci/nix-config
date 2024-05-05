{ osConfig, config, lib, ... }: lib.mkIf (true || osConfig.users.users.${config.home.username}.shell.pname == "fish") {
  programs.fish = {
    enable = true;
  };

  user.persistence.files = [
    ".local/share/fish/fish_history"
  ];
}

{ osConfig, config, lib, ... }: {
  programs.fish = lib.mkIf (osConfig.users.users.${config.home.username}.shell.pname == "fish") {
    enable = true;
  };
}

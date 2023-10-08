{ config, pkgs, ... }: {
  programs.atuin = {
    enable = false;
    package = pkgs.atuin;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableZshIntegration = config.programs.zsh.enable;
  };
}

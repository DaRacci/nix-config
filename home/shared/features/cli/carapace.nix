{ config, pkgs, ... }:
{
  programs.carapace = {
    enable = true;
    package = pkgs.carapace;

    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = false; # We have our own implementation
  };
}

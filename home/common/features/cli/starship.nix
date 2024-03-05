{ config, pkgs, ... }: {
  programs.starship = {
    enable = true;
    package = pkgs.starship;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableIonIntegration = config.programs.ion.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableZshIntegration = config.programs.zsh.enable;

    settings = { };
  };
}

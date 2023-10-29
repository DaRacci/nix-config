{ config, lib, persistenceDirectory, hasPersistence, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    enableBashIntegration = config.programs.bash.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableZshIntegration = config.programs.zsh.enable;
  };

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".direnv" ];
  };
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/direnv"
  ];
}

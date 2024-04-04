{ config, lib, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    enableBashIntegration = config.programs.bash.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableZshIntegration = config.programs.zsh.enable;
  };

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".direnv" ];
  };

  user.persistence.directories = [
    ".local/share/direnv"
  ];
}

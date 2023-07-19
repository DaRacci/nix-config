{ lib, config, persistenceDirectory, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".direnv" ];
  };

  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/direnv"
  ];
}

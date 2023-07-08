{ lib, config, persistencePath, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".direnv" ];
  };

  home.persistence."${persistencePath}".directories = [
    ".local/share/direnv"
  ];
}

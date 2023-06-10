{ lib, config, ... }: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = lib.mkIf config.programs.git.enable {
    ignores = [ ".direnv" ];
  };

  home.persistence."/persist/home/racci".directories = [
    "/.local/share/direnv"
  ];
}
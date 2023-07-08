{ pkgs, persistencePath, ... }: {
  home.packages = with pkgs; [ (unstable.lutris) ];

  home.persistence."${persistencePath}".directories = [
    ".config/lutris"
    ".local/share/lutris/games" # TODO :: Are the other folders required too?
  ];
}

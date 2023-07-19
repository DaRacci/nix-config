{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs; [ (unstable.lutris) ];

  home.persistence."${persistenceDirectory}".directories = [
    ".config/lutris"
    ".local/share/lutris/games" # TODO :: Are the other folders required too?
  ];
}

{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [ (unstable.lutris) ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/lutris"
    ".local/share/lutris/games" # TODO :: Are the other folders required too?
  ];
}

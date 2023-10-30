{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [ pods ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/pods"
  ];
}
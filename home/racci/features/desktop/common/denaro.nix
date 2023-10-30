{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs.unstable; [ denaro ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    # ".config/Nickvision/Nickvision Denaro"
  ];
}

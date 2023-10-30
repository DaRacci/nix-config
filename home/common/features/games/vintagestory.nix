{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs.unstable; [ vintagestory ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/VintagestoryData/"
  ];
}

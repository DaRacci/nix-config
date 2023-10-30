{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [ rnote ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    # TODO
  ];
}
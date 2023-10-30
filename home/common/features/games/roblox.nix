{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs.unstable; [ grapejuice ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence.${persistenceDirectory}.directories = [
    ".config/brinkervii/grapejuice"
    ".local/share/grapejuice"
  ];
}

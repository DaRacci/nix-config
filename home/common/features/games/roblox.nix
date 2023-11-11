{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs.unstable; [ grapejuice ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence.${persistenceDirectory}.directories = [
      ".config/brinkervii/grapejuice"
      ".local/share/grapejuice"
    ];
  })
]

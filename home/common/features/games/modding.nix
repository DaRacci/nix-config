# Provides a general area for modding packages,
# and their persistent directories.
{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs; [ ficsit-cli ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".local/share/ficsit"
    ];
  })
]

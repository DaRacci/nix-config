{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs.unstable; [ denaro ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      # ".config/Nickvision/Nickvision Denaro"
    ];
  })
]

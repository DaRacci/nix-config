{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs; [ obsidian ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".config/obsidian"
    ];
  })
]

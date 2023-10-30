{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  home.packages = with pkgs; [ obsidian ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".config/obsidian"
  ];
}
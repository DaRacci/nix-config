{ config, lib, persistenceDirectory, hasPersistence, ... }: {
  programs.zoxide.enable = true;
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/zoxide/"
  ];
}

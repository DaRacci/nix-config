{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  # TODO :: Ensure audio components are installed;
  home.packages = with pkgs.unstable; [ osu-lazer ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/osu"
  ];
}

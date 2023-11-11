{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    # TODO :: Ensure audio components are installed;
    home.packages = with pkgs.unstable; [ osu-lazer ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".local/share/osu"
    ];
  })
]

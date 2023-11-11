{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    # services.spotifyd = {
    #   enable = false;
    #   package = (pkgs.spotifyd.override { withKeyring = true; });
    # };

    home.packages = with pkgs; [ spot spotify spicetify-cli ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".config/spotify"
      ".cache/spot"
    ];
  })
]

{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    home.packages = with pkgs; [
      gnome-secrets
    ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}" = {
      directories = [
        ".config/1Password/settings"
      ];

      files = [
        ".config/1Password/1password.sqlite"
      ];
    };
  })
]

{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    imports = [
      # ./emacs
      ./code.nix
      ./jetbrains.nix
      # ./lapce.nix
    ];

    home.packages = with pkgs; [ nix-init ];
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      "Projects"
    ];
  })
]

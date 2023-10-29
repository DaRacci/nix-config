{ config, pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  imports = [
    # ./emacs
    ./code.nix
    ./jetbrains.nix
    # ./lapce.nix
  ];

  home.packages = with pkgs; [ nix-init ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    "Projects"
  ];
}

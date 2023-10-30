{ pkgs, lib, persistenceDirectory, hasPersistence, ... }: {
  # TODO :: Auto run protonup-rs on rebuild so you don't have to manually run it every boot.
  home.packages = with pkgs; [
    protonup-rs
    unstable.bottles
  ];
} // lib.optionalAttrs (hasPersistence) {
  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/bottles"
  ];
}

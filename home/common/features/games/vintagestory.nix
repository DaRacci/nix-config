{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs.unstable; [ vintagestory ];

  home.persistence."${persistenceDirectory}".directories = [
    ".config/VintagestoryData/"
  ];
}

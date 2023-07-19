# Provides a general area for modding packages,
# and their persistent directories.
{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs; [ ficsit-cli ];

  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/ficsit"
  ];
}

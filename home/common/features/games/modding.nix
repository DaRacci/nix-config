# Provides a general area for modding packages,
# and their persistent directories.
{ pkgs, persistencePath, ... }: {
  home.packages = with pkgs.unstable; [ ficsit-cli ];

  home.persistence."${persistencePath}".directories = [
    ".local/share/ficsit"
  ];
}

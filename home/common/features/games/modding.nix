# Provides a general area for modding packages,
# and their persistent directories.
# TODO - Only install if satisfactory is installed on steam
{ pkgs, ... }: {
  home.packages = with pkgs; [ ficsit-cli ];

  user.persistence.directories = [
    ".local/share/ficsit"
  ];
}

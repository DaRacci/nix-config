# Provides a general area for modding packages,
# and their persistent directories.
{ pkgs, ... }: {
  home.packages = with pkgs; [ ficsit-cli ];

  home.persistence."/persist/home/racci".directories = [
    ".local/share/ficsit"
  ];
}
{ pkgs, ... }: {
  home.packages = [ pkgs.ficsit-cli ];

  home.persistence."/persist/home/racci".directories = [
    ".local/share/ficsit"
  ];
}
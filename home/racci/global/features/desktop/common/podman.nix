{ pkgs, ... }: {
  home.packages = with pkgs; [ pods ];

  home.persistence."/persist/home/racci".directories = [
    ".config/pods"
  ];
}
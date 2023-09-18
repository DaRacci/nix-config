{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ denaro ];

  home.persistence."/persist/home/racci".directories = [
    # ".config/Nickvision/Nickvision Denaro"
  ];
}

{ pkgs, ... }: {
  home.packages = with pkgs; [ denaro ];

  home.persistence."/persist/home/racci".directories = [
    # TODO
  ];
}
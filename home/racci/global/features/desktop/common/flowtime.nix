{ pkgs, ... }: {
  home.packages = with pkgs; [ flowtime ];

  home.persistence."/persist/home/racci".directories = [
    # TODO
  ];
}
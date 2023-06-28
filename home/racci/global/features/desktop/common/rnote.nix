{ pkgs, ... }: {
  home.packages = with pkgs; [ rnote ];

  home.persistence."/persist/home/racci".directories = [
    # TODO
  ];
}
{ pkgs, ... }: {
  home.packages = with pkgs; [ gnome-builder ];

  home.persistence."/persist/home/racci".directories = [
    # TODO
  ];
}
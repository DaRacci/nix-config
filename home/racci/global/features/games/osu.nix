{ config, pkgs, lib, ... }: {
  home.packages = [ pkgs.osu-lazer ];

  home.persistence."/persist/home/racci".directories = [{
    directory = ".local/share/osu";
  }];
}

{ pkgs, ... }: {
  home.packages = with pkgs; [ obsidian ];

  home.persistence."/persist/home/racci".directories = [
    ".config/obsidian"
  ];
}
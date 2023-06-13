{ pkgs, ... }: {
  home.packages = with pkgs; [
    winePackages.stagingFull
    bottles
  ];

  home.persistence."/persist/home/racci".directories = [
    ".local/share/bottles"
  ];
}
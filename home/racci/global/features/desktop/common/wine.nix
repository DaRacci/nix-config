{ pkgs, ... }: {
  home.packages = with pkgs; [
    winePackages.stagingFull
  ];
}
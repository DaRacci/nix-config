{ pkgs, ... }: {
  home.packages = with pkgs; [
    aichat
    unstable.tgpt
  ];
}
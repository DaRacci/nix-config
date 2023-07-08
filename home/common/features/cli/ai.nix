{ pkgs, persistencePath, ... }: {
  home.packages = with pkgs; [
    unstable.tgpt
  ];

  home.persist."${persistencePath}".directories = [
    ".config/tgpt"
  ];
}

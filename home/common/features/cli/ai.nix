{ pkgs, persistenceDirectory, ... }: {
  home.packages = with pkgs; [
    unstable.tgpt
  ];

  home.persistence."${persistenceDirectory}".directories = [
    ".config/tgpt"
  ];
}

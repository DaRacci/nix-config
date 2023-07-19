{ persistenceDirectory, ... }: {
  programs.zoxide.enable = true;

  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/zoxide/"
  ];
}

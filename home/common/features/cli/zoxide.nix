{ persistencePath, ... }: {
  programs.zoxide.enable = true;

  home.persistence."${persistencePath}".directories = [
    ".local/share/zoxide/"
  ];
}

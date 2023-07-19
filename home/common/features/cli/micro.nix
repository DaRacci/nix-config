{ persistenceDirectory, ... }: {
  programs.micro = {
    enable = true;
    settings = {
      autosu = true;
      diffgutter = true;
      hlsearch = true;
      mkparents = true;
      saveundo = true;
      tabmovement = false;
      tabstospaces = true;
    };
  };

  home.persistence."${persistenceDirectory}".directories = [
    ".config/micro/buffers"
    ".config/micro/backup"
  ];
}

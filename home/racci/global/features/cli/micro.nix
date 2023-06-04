{ config, ...}: {
  home.persistence."/persist/home/${config.home.username}".directories = [
    ".config/micro/buffers"
    ".config/micro/backup"
  ];

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
}
_: {
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

  # home.sessionVariables = {
  #   EDITOR = "${pkgs.micro}/bin/micro";
  # };

  user.persistence.directories = [
    ".config/micro/buffers"
    ".config/micro/backup"
  ];
}

{ config, pkgs, lib, persistenceDirectory, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
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

    home.sessionVariables = {
      EDITOR = "${pkgs.micro}/bin/micro";
    };
  }
  (lib.optionalAttrs (hasPersistence) {
    home.persistence."${persistenceDirectory}".directories = [
      ".config/micro/buffers"
      ".config/micro/backup"
    ];
  })
]

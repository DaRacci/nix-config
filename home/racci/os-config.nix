{ config, pkgs, ... }: {
  users.users.racci = {
    uid = 1000;
    shell = pkgs.nushell;
  };

  environment.shells = [ config.users.users.racci.shell ];
}

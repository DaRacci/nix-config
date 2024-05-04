{ pkgs, ... }: {
  users.users.racci = {
    uid = 1000;
    shell = pkgs.nushell;
  };
}

{ pkgs, ... }: {
  users.users.root = {
    shell = pkgs.fish;
  };
}

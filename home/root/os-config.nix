{ pkgs, lib, ... }:
let inherit (lib) mkForce; in {
  users.users.root = {
    shell = pkgs.fish;
    home.homeDirectory = mkForce "/root";
  };
}

{ pkgs, lib, ... }:
let inherit (lib) mkForce; in {
  users.users.root = {
    shell = pkgs.fish;
    hashedPasswordFile = null;
    isNormalUser = mkForce false;
  };
}

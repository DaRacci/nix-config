{ pkgs, lib, ... }:
let inherit (lib) mkForce; in {
  users.users.root = {
    shell = pkgs.fish;
    isNormalUser = mkForce false;
  };

  programs.fish.enable = true;
}

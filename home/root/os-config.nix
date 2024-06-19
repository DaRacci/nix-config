{ flake, pkgs, lib, ... }:
let inherit (lib) mkForce; in {
  users.users.root = {
    shell = pkgs.fish;
    isNormalUser = mkForce false;

    openssh.authorizedKeys.keyFiles = [
      "${flake}/home/racci/id_ed25519.pub"
    ];
  };

  programs.fish.enable = true;
}

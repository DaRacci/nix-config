{ flake, config, pkgs, lib, ... }:
let
  inherit (lib) mkForce;
  # WSL is fucky with nu so we use fish instead.
  useFish = builtins.hasAttr "wsl" config;
in
{
  users.users.root = {
    shell =
      if useFish
      then pkgs.fish
      else pkgs.nushell;
    isNormalUser = mkForce false;

    openssh.authorizedKeys.keyFiles = [
      "${flake}/home/racci/id_ed25519.pub"
    ];
  };

  programs.fish.enable = useFish;
}

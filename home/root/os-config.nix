{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkForce;
  # WSL is fucky with nu so we use fish instead, same with proxmox LXC.
  useFish = builtins.hasAttr "wsl" config || config.host.device.role == "server";
in
{
  users.users.root = {
    shell = if useFish then pkgs.fish else pkgs.nushell;
    isNormalUser = mkForce false;

    openssh.authorizedKeys.keyFiles = [ "${self}/home/racci/id_ed25519.pub" ];
  };

  programs.fish.enable = useFish;
}

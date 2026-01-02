{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkForce mkAfter;
  # WSL is fucky with nu so we use fish instead, same with proxmox LXC.
  useFish = builtins.hasAttr "wsl" config;
  useNu = config.host.device.role != "server";
in
{
  users.users.root = {
    shell =
      if useFish then
        pkgs.fish
      else if useNu then
        pkgs.nushell
      else
        pkgs.bash;
    isNormalUser = mkForce false;

    openssh.authorizedKeys.keyFiles = mkAfter [ "${self}/home/racci/id_ed25519.pub" ];
  };

  programs.fish.enable = useFish;
}

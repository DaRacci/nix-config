{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    ./immich.nix
    ./nextcloud.nix
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };
}

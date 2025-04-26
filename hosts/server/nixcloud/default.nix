{ ... }:
{
  imports = [
    ./homebox.nix
    ./immich.nix
    ./nextcloud.nix
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };
}

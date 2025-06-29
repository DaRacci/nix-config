{ ... }:
{
  imports = [
    ./home-assistant
    ./homebox.nix
    # ./immich.nix
    ./identity.nix
    ./nextcloud.nix
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };
}

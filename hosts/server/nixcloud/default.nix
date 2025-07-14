{ ... }:
{
  imports = [
    ./home-assistant
    ./homebox.nix
    # ./immich.nix
    ./mqtt.nix
    ./identity.nix
    ./nextcloud.nix
    ./search.nix
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
    manageHostName = false;
  };
}

{ ... }:
{
  imports = [
    ./home-assistant
    ./homebox.nix
    ./immich.nix
    ./music.nix
    ./identity.nix
    ./nextcloud.nix
    ./search.nix
  ];

  proxmoxLXC = {
    privileged = false;
  };
}

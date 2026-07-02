{ ... }:
{
  imports = [
    ./home-assistant
    ./homebox.nix
    ./immich.nix
    ./music.nix
    ./nextcloud.nix
    ./search.nix
  ];

  server.dashboard.icon = "sh-icloud";

  proxmoxLXC = {
    privileged = false;
  };
}

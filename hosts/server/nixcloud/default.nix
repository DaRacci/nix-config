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

  server.sshGuard.endpoints = [
    "http://127.0.0.1/status.php"
    "http://127.0.0.1:2283/api/server/ping"
    "http://127.0.0.1:9200/_cluster/health"
  ];

  server.dashboard.icon = "sh-icloud";

  proxmoxLXC = {
    privileged = false;
  };
}

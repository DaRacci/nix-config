{
  ...
}:
{
  imports = [
    ./automation.nix
    ./ci.nix
    ./coder.nix
    ./forgesync.nix
    ./registry.nix
    ./woodpecker.nix
  ];

  server.sshGuard.endpoints = [
    "http://127.0.0.1:5678/healthz"
    "http://127.0.0.1:8080/healthz"
    "http://127.0.0.1:8000/healthz"
    "http://127.0.0.1:5000/v2/"
  ];

  server.dashboard.icon = "mdi-code-braces";

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [
      8080
      2525
    ];
  };
}

{
  ...
}:
{
  imports = [
    ./automation.nix
    ./ci.nix
    ./coder.nix
    ./registry.nix
    ./woodpecker.nix
  ];

  server.dashboard.icon = "mdi-code-braces";

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    daemon.settings.storage-driver = "overlayfs";
  };

  networking.firewall = {
    allowedTCPPorts = [
      8080
      2525
    ];
  };
}

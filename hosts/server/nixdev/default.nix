{
  ...
}:
{
  imports = [
    ./atuin.nix
    ./automation.nix
    ./ci.nix
    ./coder.nix
    ./forgesync.nix
    ./registry.nix
    ./woodpecker.nix
  ];

  server.dashboard.icon = "mdi-code-braces";

  services.atuin.enable = true;

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

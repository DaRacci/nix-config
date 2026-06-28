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
  };

  networking.firewall = {
    allowedTCPPorts = [
      8080
      2525
    ];
  };

  server.tests.units = {
    docker = {
      testScript = ''
        nixdev.succeed("systemctl show docker.service | grep -i loadstate")
      '';
    };
  };
}

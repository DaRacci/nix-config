{
  ...
}:
{
  imports = [
    ./automation.nix
    ./ci.nix
  ];

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

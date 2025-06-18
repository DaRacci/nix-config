{
  services.matter-server = {
    enable = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 5580 ];
    allowedUDPPorts = [ 5580 ];
  };
}
